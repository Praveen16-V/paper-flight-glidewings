import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';
import '../models/run_result.dart';
import '../providers/game_session_provider.dart';
import '../providers/save_data_provider.dart';
import '../providers/settings_provider.dart';
// RunSnapshot lives in game_session_provider.dart
import 'components/background/parallax_background.dart';
import 'components/background/wind_lane_overlay.dart';
import 'components/plane_component.dart';
import 'systems/input_manager.dart';
import 'systems/obstacle_spawner.dart';
import 'systems/collectible_spawner.dart';
import 'systems/powerup_spawner.dart';
import 'systems/scoring_system.dart';
import 'systems/wind_system.dart';
import 'systems/biome_manager.dart';

/// The root FlameGame — Paper Flight / Driftpaper.
///
/// Architecture (GDD §13):
///   - Static camera/viewport — no camera-follow needed.
///   - World scrolls downward via [_scrollSpeed]; obstacles/coins translate
///     each frame by scrollSpeed × dt.
///   - Plane X/Y are driven entirely by [InputManager] — position is dodge
///     space, not progress space.
///   - Progress = [_distanceMeters], driven by scrollSpeed × elapsed time.
class PaperFlightGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, DragCallbacks {
  PaperFlightGame({required this.ref});

  /// Riverpod ref — lets game systems push state to providers without
  /// needing a BuildContext.
  final WidgetRef ref;

  // ── Scroll / Speed ────────────────────────────────────────────────────────

  double _scrollSpeed = GameConfig.baseScrollSpeed;
  double get scrollSpeed => _scrollSpeed;

  double _distanceMeters = 0;
  double get distanceMeters => _distanceMeters;

  /// Slow-mo multiplier (1.0 = normal, <1.0 during slow-mo power-up).
  double _timeScale = 1.0;
  double get timeScale => _timeScale;

  // ── Systems ───────────────────────────────────────────────────────────────

  late final InputManager inputManager;
  late final WindSystem windSystem;
  late final ScoringSystem scoringSystem;
  late final BiomeManager biomeManager;
  late final ObstacleSpawner obstacleSpawner;
  late final CollectibleSpawner collectibleSpawner;
  late final PowerUpSpawner powerUpSpawner;

  // ── Core Components ───────────────────────────────────────────────────────

  late final PlaneComponent plane;
  late final ParallaxBackground background;

  // ── State ─────────────────────────────────────────────────────────────────

  GamePhase _phase = GamePhase.idle;
  GamePhase get phase => _phase;

  bool _isReviving = false;
  bool _pendingStartWithShield = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Color backgroundColor() => const Color(0xFF1A2744);

  @override
  Future<void> onLoad() async {
    // Static camera — fixed viewport, no follow logic.
    camera = CameraComponent.withFixedResolution(
      width: GameConfig.designWidth,
      height: GameConfig.designHeight,
    )..viewfinder.anchor = Anchor.topLeft;

    // Background parallax layers (farthest first).
    background = ParallaxBackground();
    world.add(background);
    world.add(WindLaneOverlay());

    // Core systems (order matters — input before plane, wind before obstacles).
    inputManager = InputManager(game: this);
    windSystem = WindSystem();
    scoringSystem = ScoringSystem(game: this);
    biomeManager = BiomeManager(game: this);

    world.add(inputManager);
    world.add(windSystem);
    world.add(scoringSystem);
    world.add(biomeManager);

    // Spawners.
    obstacleSpawner = ObstacleSpawner(game: this);
    collectibleSpawner = CollectibleSpawner(game: this);
    powerUpSpawner = PowerUpSpawner(game: this);

    world.add(obstacleSpawner);
    world.add(collectibleSpawner);
    world.add(powerUpSpawner);

    // Plane — added last so it renders on top of obstacles (z-order by add).
    final save = ref.read(saveDataProvider);
    plane = PlaneComponent(
      game: this,
      planeType: PlaneType.values[save.equippedPlaneIndex.clamp(
        0,
        PlaneType.values.length - 1,
      )],
    );
    world.add(plane);

    // Apply current settings to input.
    _syncSettings();

    // Biome transitions update background palette.
    biomeManager.addTransitionListener((from, to) {
      background.transitionToBiome(to);
    });

    await super.onLoad();
  }

  void _syncSettings() {
    final settings = ref.read(settingsProvider);
    inputManager.updateSensitivity(settings.tiltSensitivity);
    inputManager.updateControlScheme(settings.controlScheme);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (_phase != GamePhase.playing) {
      super.update(dt);
      return;
    }

    final scaledDt = dt * _timeScale;

    // Accelerate scroll over time.
    _scrollSpeed = (_scrollSpeed + GameConfig.scrollAcceleration * scaledDt)
        .clamp(GameConfig.baseScrollSpeed, GameConfig.maxScrollSpeed);

    // Apply turbo/slow-mo speed overrides.
    final session = ref.read(gameSessionProvider);
    double effectiveSpeed = _scrollSpeed;
    if (session.activePowerUps.contains(PowerUpType.turboGust)) {
      effectiveSpeed *= GameConfig.turboPowerUpMultiplier;
    } else if (session.activePowerUps.contains(PowerUpType.slowMo)) {
      effectiveSpeed *= GameConfig.slowMoPowerUpMultiplier;
    }

    // Accumulate distance (px→meters factor of /10).
    _distanceMeters += effectiveSpeed * scaledDt / 10.0;

    // Push a temporary effective scroll speed so spawners/components use it.
    _effectiveScrollSpeed = effectiveSpeed;

    super.update(scaledDt);

    // Push distance to provider for HUD.
    ref.read(gameSessionProvider.notifier).updateDistance(_distanceMeters);
  }

  /// Effective scroll speed after power-up modifiers — used by spawners.
  double _effectiveScrollSpeed = GameConfig.baseScrollSpeed;
  double get effectiveScrollSpeed => _effectiveScrollSpeed;

  // ── Public API ────────────────────────────────────────────────────────────

  void startRun({bool withShield = false}) {
    _scrollSpeed = GameConfig.baseScrollSpeed;
    _effectiveScrollSpeed = GameConfig.baseScrollSpeed;
    _distanceMeters = 0;
    _timeScale = 1.0;
    _phase = GamePhase.playing;
    _isReviving = false;
    _pendingStartWithShield = withShield;

    _syncSettings();

    plane.reset();
    inputManager.reset();
    obstacleSpawner.reset();
    collectibleSpawner.reset();
    powerUpSpawner.reset();
    scoringSystem.reset();
    biomeManager.reset();
    windSystem.reset();
    background.transitionToBiome(Biome.backyard);

    ref.read(gameSessionProvider.notifier).startRun();

    if (withShield || _pendingStartWithShield) {
      ref.read(gameSessionProvider.notifier).activatePowerUp(PowerUpType.shield);
      _pendingStartWithShield = false;
    }

    if (paused) resumeEngine();
  }

  /// Called by PlaneComponent / ObstacleComponent when a hit or bottom-fall occurs.
  void onPlaneCrash() {
    if (_phase != GamePhase.playing) return;

    final session = ref.read(gameSessionProvider);

    // Shield absorbs the hit.
    if (session.shieldActive) {
      ref.read(gameSessionProvider.notifier).consumeShield();
      plane.playShieldHitAnimation();
      scoringSystem.onObstacleHit();
      return;
    }

    scoringSystem.onObstacleHit();
    _phase = GamePhase.dying;
    plane.playCrashAnimation();

    // Snapshot progress so a rewarded-ad revive can restore it.
    ref.read(gameSessionProvider.notifier).saveCrashSnapshot(RunSnapshot(
          score: session.score,
          distanceMeters: _distanceMeters,
          coinsThisRun: session.coinsThisRun,
          nearMissesThisRun: session.nearMissesThisRun,
          comboCount: session.comboCount,
          comboMultiplier: session.comboMultiplier,
          currentBiome: session.currentBiome,
          scrollSpeed: _scrollSpeed,
        ));

    pauseEngine();

    // Brief freeze then transition to game over (GDD §12 juice).
    // Do NOT permanently record the run yet — GameOverScreen records on
    // Retry/Menu so a revive doesn't double-count coins/runs.
    Future.delayed(GameConfig.crashSlowMoFreeze, () {
      if (_phase != GamePhase.dying) return;
      resumeEngine();
      _phase = GamePhase.gameOver;

      final result = RunResult(
        score: session.score,
        distanceMeters: _distanceMeters,
        coinsCollected: session.coinsThisRun,
        nearMisses: session.nearMissesThisRun,
        isNewHighScore: session.score >
            ref.read(saveDataProvider).highScore,
        finalBiome: session.currentBiome,
        wasRevived: !session.canRevive,
      );
      ref.read(gameSessionProvider.notifier).triggerGameOver(result);
    });
  }

  /// Restore a run from [RunSnapshot] after navigating back from game-over.
  /// Called by GameScreen when args.revive == true.
  void startRunFromSnapshot(RunSnapshot snap) {
    _scrollSpeed = snap.scrollSpeed.clamp(
      GameConfig.baseScrollSpeed,
      GameConfig.maxScrollSpeed,
    );
    _effectiveScrollSpeed = _scrollSpeed;
    _distanceMeters = snap.distanceMeters;
    _timeScale = 1.0;
    _phase = GamePhase.playing;
    _isReviving = false;

    _syncSettings();

    plane.reset();
    plane.revive();
    inputManager.reset();
    obstacleSpawner.reset();
    collectibleSpawner.reset();
    powerUpSpawner.reset();
    // Restore scoring accumulators from snapshot.
    scoringSystem.restore(
      coins: snap.coinsThisRun,
      nearMisses: snap.nearMissesThisRun,
      comboCount: snap.comboCount,
      comboMultiplier: snap.comboMultiplier,
      coinScoreHint: snap.score,
    );
    biomeManager.restore(snap.currentBiome);
    windSystem.reset();
    background.transitionToBiome(snap.currentBiome);

    ref.read(gameSessionProvider.notifier).restoreFromSnapshot(snap);

    if (paused) resumeEngine();
  }

  /// In-place revive (same game instance) — continue from crash point.
  void revive() {
    if (_phase != GamePhase.gameOver && _phase != GamePhase.dying) return;
    if (_isReviving) return;

    final session = ref.read(gameSessionProvider);
    if (!session.canRevive) return;

    _isReviving = true;
    _phase = GamePhase.playing;

    obstacleSpawner.clearNearPlane(plane.position.y, radius: 200);
    plane.revive();
    ref.read(gameSessionProvider.notifier).useRevive();

    if (paused) resumeEngine();
    _isReviving = false;
  }

  void pauseRun() {
    if (_phase != GamePhase.playing) return;
    _phase = GamePhase.paused;
    pauseEngine();
    ref.read(gameSessionProvider.notifier).pause();
  }

  void resumeRun() {
    if (_phase != GamePhase.paused) return;
    _phase = GamePhase.playing;
    resumeEngine();
    ref.read(gameSessionProvider.notifier).resume();
  }

  void applySlowMo(double duration) {
    _timeScale = GameConfig.slowMoPowerUpMultiplier;
    Future.delayed(Duration(milliseconds: (duration * 1000).toInt()), () {
      _timeScale = 1.0;
      ref
          .read(gameSessionProvider.notifier)
          .deactivatePowerUp(PowerUpType.slowMo);
    });
  }

  // ── Input passthrough (FlameGame tap/drag → InputManager) ─────────────────

  Vector2 _dragPos = Vector2.zero();

  /// Convert device/canvas position into design-resolution coordinates.
  Vector2 _toDesignCoords(Vector2 devicePos) {
    final canvasSize = size;
    if (canvasSize.x <= 0 || canvasSize.y <= 0) return devicePos.clone();
    final scaleX = GameConfig.designWidth / canvasSize.x;
    final scaleY = GameConfig.designHeight / canvasSize.y;
    return Vector2(devicePos.x * scaleX, devicePos.y * scaleY);
  }

  @override
  void onTapDown(TapDownEvent event) {
    inputManager.onTapDown(_toDesignCoords(event.localPosition));
  }

  @override
  void onTapUp(TapUpEvent event) {
    inputManager.onTapUp(_toDesignCoords(event.localPosition));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragPos = _toDesignCoords(event.localPosition);
    inputManager.onDragStart(_dragPos);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    // Accumulate from localDelta (always present on DisplacementEvent).
    final scaleX = size.x > 0 ? GameConfig.designWidth / size.x : 1.0;
    final scaleY = size.y > 0 ? GameConfig.designHeight / size.y : 1.0;
    _dragPos += Vector2(
      event.localDelta.x * scaleX,
      event.localDelta.y * scaleY,
    );
    inputManager.onDragUpdate(_dragPos);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    inputManager.onDragEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    inputManager.onDragEnd();
  }
}
