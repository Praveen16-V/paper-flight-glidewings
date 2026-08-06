import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';
import '../models/run_result.dart';
import '../providers/game_session_provider.dart';
import '../providers/save_data_provider.dart';
import 'components/background/parallax_background.dart';
import 'components/effects/coin_feedback.dart';
import 'components/plane_component.dart';
import 'systems/input_manager.dart';
import 'systems/obstacle_spawner.dart';
import 'systems/collectible_spawner.dart';
import 'systems/powerup_spawner.dart';
import 'systems/scoring_system.dart';
import 'systems/wind_system.dart';
import 'systems/biome_manager.dart';

/// The root FlameGame — Paper Flight.
///
/// Architecture:
///   - Static camera/viewport — no camera-follow needed (per GDD §13).
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

  /// Accumulator for periodic Coin Rush coin showers.
  double _coinRushShowerTimer = 0;

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
      planeType: PlaneType.values[save.equippedPlaneIndex],
    );
    world.add(plane);

    await super.onLoad();
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (_phase != GamePhase.playing) {
      super.update(dt);
      return;
    }

    final scaledDt = dt * _timeScale;

    // Apply slow-mo speed override (drives this frame's motion and the
    // distance it travels).
    final session = ref.read(gameSessionProvider);
    double effectiveSpeed = _scrollSpeed;
    if (session.activePowerUps.contains(PowerUpType.slowMo)) {
      effectiveSpeed *= GameConfig.slowMoPowerUpMultiplier;
    }

    // Accumulate distance from this frame's effective speed.
    _distanceMeters += effectiveSpeed * scaledDt / 10.0; // px→meters factor

    // Scroll speed is a pure function of distance reached — the world only
    // speeds up as the player travels further, ramping in gradually instead
    // of accelerating by wall-clock time. Power-up overrides are applied next
    // frame against this updated base.
    _scrollSpeed = _scrollSpeedForDistance(_distanceMeters);

    super.update(dt);

    // Coin Rush: keep raining coin showers down for the power-up's duration.
    if (session.activePowerUps.contains(PowerUpType.coinRush)) {
      _coinRushShowerTimer += scaledDt;
      if (_coinRushShowerTimer >= GameConfig.coinRushShowerInterval) {
        _coinRushShowerTimer = 0;
        collectibleSpawner.spawnCoinShower();
      }
    }

    // Push distance to provider for HUD (throttled — every 5 frames approx).
    if ((_distanceMeters * 10).toInt() % 5 == 0) {
      ref
          .read(gameSessionProvider.notifier)
          .updateDistance(_distanceMeters);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Scroll speed for a given distance reached, clamped to [min, max].
  ///
  /// Because it is a pure function of meters traveled, the ramp-up is identical
  /// regardless of power-ups or frame rate — distance is the only driver.
  double _scrollSpeedForDistance(double meters) =>
      (GameConfig.baseScrollSpeed + GameConfig.scrollSpeedPerMeter * meters)
          .clamp(GameConfig.baseScrollSpeed, GameConfig.maxScrollSpeed);

  void startRun() {
    _scrollSpeed = GameConfig.baseScrollSpeed;
    _distanceMeters = 0;
    _timeScale = 1.0;
    _coinRushShowerTimer = 0;
    _phase = GamePhase.playing;
    _isReviving = false;

    plane.reset();
    obstacleSpawner.reset();
    collectibleSpawner.reset();
    powerUpSpawner.reset();
    scoringSystem.reset();
    biomeManager.reset();
    windSystem.reset();

    ref.read(gameSessionProvider.notifier).startRun();
  }

  /// Called by PlaneComponent when it hits an obstacle.
  void onPlaneCrash() {
    if (_phase != GamePhase.playing) return;

    final session = ref.read(gameSessionProvider);

    // Ghost: the plane phases straight through every obstacle.
    if (session.activePowerUps.contains(PowerUpType.ghost)) {
      plane.playGhostPhaseAnimation();
      return;
    }

    // Shield absorbs the hit.
    if (session.shieldActive) {
      ref.read(gameSessionProvider.notifier).consumeShield();
      plane.playShieldHitAnimation();
      return;
    }

    _phase = GamePhase.dying;
    spawnCrashFeedback(this, plane.position);
    pauseEngine();

    // Brief freeze then transition to game over.
    Future.delayed(GameConfig.crashSlowMoFreeze, () {
      resumeEngine();
      _phase = GamePhase.gameOver;
      _finalizeRun(wasRevived: false);
    });
  }

  /// Called by rewarded-ad revive flow.
  void revive() {
    if (_isReviving || _phase != GamePhase.gameOver) return;
    _isReviving = true;
    _phase = GamePhase.playing;
    plane.revive();
    ref.read(gameSessionProvider.notifier).useRevive();
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
      ref.read(gameSessionProvider.notifier).deactivatePowerUp(PowerUpType.slowMo);
    });
  }

  /// Kicks off the Coin Rush power-up: immediately rains an opening coin shower
  /// and resets the periodic-shower timer.
  void beginCoinRush() {
    _coinRushShowerTimer = 0;
    collectibleSpawner.spawnCoinShower();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _finalizeRun({required bool wasRevived}) async {
    final session = ref.read(gameSessionProvider);
    final notifier = ref.read(saveDataProvider.notifier);

    final isNew = await notifier.recordRunResult(
      score: session.score,
      distanceMeters: _distanceMeters,
      coinsEarned: session.coinsThisRun,
      nearMisses: session.nearMissesThisRun,
    );

    final result = RunResult(
      score: session.score,
      distanceMeters: _distanceMeters,
      coinsCollected: session.coinsThisRun,
      nearMisses: session.nearMissesThisRun,
      isNewHighScore: isNew,
      finalBiome: session.currentBiome,
      wasRevived: wasRevived,
    );

    ref.read(gameSessionProvider.notifier).triggerGameOver(result);
  }

  // ── Input passthrough (FlameGame tap/drag → InputManager) ─────────────────

  @override
  void onTapDown(TapDownEvent event) {
    inputManager.onTapDown(event.devicePosition);
  }

  @override
  void onTapUp(TapUpEvent event) {
    inputManager.onTapUp(event.devicePosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    inputManager.onDragStart(event.devicePosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    inputManager.onDragEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    inputManager.onDragEnd();
  }
}
