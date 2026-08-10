import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart' hide JoystickComponent;
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';
import '../models/run_result.dart';
import '../models/settings_model.dart';
import '../models/trial_definition.dart';
import '../providers/game_session_provider.dart';
import '../providers/save_data_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analytics_service.dart';
import '../services/daily_leaderboard_service.dart';
import '../services/daily_seed_service.dart';
import 'components/background/parallax_background.dart';
import 'components/effects/coin_feedback.dart';
import 'components/effects/atmosphere_component.dart';
import 'components/joystick_component.dart';
import 'components/obstacles/obstacle_component.dart';
import 'components/plane_component.dart';
import 'components/touch_zones_overlay.dart';
import 'systems/input_manager.dart';
import 'systems/obstacle_spawner.dart';
import 'systems/collectible_spawner.dart';
import 'systems/powerup_spawner.dart';
import 'systems/scoring_system.dart';
import 'systems/streak_system.dart';
import 'systems/trial_director.dart';
import 'systems/wind_system.dart';
import 'systems/biome_manager.dart';
import 'systems/game_feel_system.dart';

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
  PaperFlightGame({
    required this.ref,
    this.mode = GameMode.classic,
    this.trialId,
  });

  /// Riverpod ref — lets game systems push state to providers without
  /// needing a BuildContext.
  final WidgetRef ref;

  // ── Game Mode (Task 8) ────────────────────────────────────────────────────

  /// Which mode this game instance runs: classic, zen, daily or trial.
  final GameMode mode;

  /// Trial id when [mode] is [GameMode.trial].
  final int? trialId;

  /// The handcrafted course for this run (null outside trials).
  TrialDefinition? get trial =>
      trialId == null ? null : TrialPool.byId(trialId!);

  /// Seed of today's Daily Seeded Flight (UTC-based, same for all players).
  int get dailySeed => DailySeedService.seedForNow();

  /// Seed-aware RNG shared by the spawners. The Daily Seeded Flight derives
  /// per-system generators from [dailySeed] so every player gets the exact
  /// same obstacle, coin and power-up layout regardless of frame timing.
  late math.Random _spawnRng;
  math.Random get spawnRng => _spawnRng;

  /// Trial director — active only in [GameMode.trial].
  TrialDirector? trialDirector;

  // ── Zen Flight state ──────────────────────────────────────────────────────

  /// Seconds remaining of Zen bump immunity.
  double _zenBounceCooldown = 0;

  // ── Scroll / Speed ────────────────────────────────────────────────────────

  double _scrollSpeed = GameConfig.baseScrollSpeed;
  double get scrollSpeed => _scrollSpeed;

  double _distanceMeters = 0;
  double get distanceMeters => _distanceMeters;

  /// Wall-clock seconds of the current run (Zen + trial HUD).
  double _runTimeSeconds = 0;
  double get runTimeSeconds => _runTimeSeconds;

  /// Slow-mo multiplier (1.0 = normal, <1.0 during slow-mo power-up).
  double _timeScale = 1.0;
  double get timeScale => _timeScale;

  /// Accumulator for periodic Coin Rush coin showers.
  double _coinRushShowerTimer = 0;

  // ── Systems ───────────────────────────────────────────────────────────────

  late final InputManager inputManager;
  late final WindSystem windSystem;
  late final ScoringSystem scoringSystem;
  late final StreakSystem streakSystem;
  late final BiomeManager biomeManager;
  late final ObstacleSpawner obstacleSpawner;
  late final CollectibleSpawner collectibleSpawner;
  late final PowerUpSpawner powerUpSpawner;

  /// Juice layer — adaptive audio, dynamic camera, streaks, chimes & haptics.
  late final GameFeelSystem gameFeelSystem;

  // ── Core Components ───────────────────────────────────────────────────────

  late final PlaneComponent plane;
  late final ParallaxBackground background;
  late final AtmosphereComponent atmosphere;

  // ── On-screen control visuals (joystick / touch-zone guides) ─────────────

  late final JoystickComponent joystickComponent;
  late final TouchZonesOverlay touchZonesOverlay;

  // ── State ─────────────────────────────────────────────────────────────────

  GamePhase _phase = GamePhase.idle;
  GamePhase get phase => _phase;

  /// Set once [dispose] has run. Any in-flight `Future.delayed` callbacks
  /// (crash freeze, trial freeze, power-up timers, death-defying hit-stop)
  /// check this so they never touch a torn-down game/world.
  bool _disposed = false;
  bool get isDisposed => _disposed;

  bool _isReviving = false;

  /// Guards the Death Defying hit-stop so overlapping awards can't stack
  /// pause/resume cycles on top of each other (or of the crash freeze).
  bool _deathDefyingFreezeActive = false;

  // ── Challenge Run Tracking (Task 7) ───────────────────────────────────────

  int _thermalsEnteredThisRun = 0;
  bool _wasInThermal = false;
  int _maxComboThisRun = 0;
  Biome _biomeAtMaxCombo = Biome.city;
  int _maxComboInStormThisRun = 0;
  int _buildingGapsPassedThisRun = 0;
  bool _powerUpUsedThisRun = false;
  int _powerUpsUsedThisRun = 0;
  String _lastCrashCause = 'unknown';

  // Flutter/provider synchronization is intentionally outside the 60/120 Hz
  // hot path. The Flame world still updates every frame.
  double _hudUpdateAccumulator = 0;
  double _runtimeStateSyncAccumulator = 0;

  // Crane free brush-off charges remaining this run.
  int _craneChargesRemaining = 0;

  // Extra shield charges (e.g. Paper Bomber starting shield).
  int _shieldChargesRemaining = 0;

  // Decoy clone charges remaining.
  int _decoyCloneCharges = 0;
  int get decoyCloneCharges => _decoyCloneCharges;

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

    // Air is a first-class gameplay layer: it renders before hazards and plane.
    atmosphere = AtmosphereComponent();
    world.add(atmosphere);

    // Core systems (order matters — input before plane, wind before obstacles).
    inputManager = InputManager(game: this);
    // Wind is seeded per mode: daily uses the UTC day seed (identical for
    // every player), trials use a fixed per-course seed, zen/classic wander.
    final windSeed = switch (mode) {
      GameMode.daily => dailySeed,
      GameMode.trial => 1000 + (trialId ?? 0),
      GameMode.zen || GameMode.classic => null,
    };
    windSystem = WindSystem(seed: windSeed);
    scoringSystem = ScoringSystem(game: this);
    streakSystem = StreakSystem();
    biomeManager = BiomeManager(game: this);

    world.add(inputManager);
    world.add(windSystem);
    world.add(scoringSystem);
    world.add(streakSystem);
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
    final planeType = PlaneType.values[save.equippedPlaneIndex.clamp(0, PlaneType.values.length - 1)];
    final skin = PaperSkin.values[save.equippedSkinIndex.clamp(0, PaperSkin.values.length - 1)];
    final planeLvl = save.getPlaneLevel(save.equippedPlaneIndex);
    plane = PlaneComponent(
      game: this,
      planeType: planeType,
      paperSkin: skin,
      planeLevel: planeLvl,
    );
    world.add(plane);

    // On-screen control visuals — on top of everything (z-order by add).
    joystickComponent = JoystickComponent(inputManager: inputManager);
    touchZonesOverlay = TouchZonesOverlay(inputManager: inputManager);
    world.add(joystickComponent);
    world.add(touchZonesOverlay);

    // Game-feel juice layer — added last so its vignette/streak overlay draws
    // on top of the whole world.
    gameFeelSystem = GameFeelSystem();
    world.add(gameFeelSystem);

    // Sync initial control scheme + sensitivity from persisted settings.
    try {
      final settings = ref.read(settingsProvider);
      inputManager.updateControlScheme(settings.controlScheme);
      inputManager.updateSensitivity(settings.tiltSensitivity);
      inputManager.updateGesturePowerUp(settings.flickToUsePowerUp);
      _syncOnScreenControlsVisibility(settings);
    } catch (_) {}

    await super.onLoad();
  }

  /// Called by Flame when the hosting GameWidget is removed from the widget
  /// tree (which happens every time the player taps Retry / Menu and the
  /// GameScreen is replaced).
  ///
  /// This is the single most important teardown for the "game hangs after
  /// playing multiple times" bug: previously [GameScreen.dispose] only paused
  /// the engine, so each prior run's game — along with its accelerometer
  /// stream subscription ([InputManager]), audio players ([GameFeelSystem])
  /// and the entire component/world tree — was never released. Those stale
  /// games piled up run after run until the app hung.
  @override
  void onRemove() {
    // Framework-driven teardown (GameWidget detaching). Flame does not
    // auto-cascade child removal here, so ask for it explicitly.
    _releaseResources(cascadeChildren: true);
    super.onRemove();
  }

  /// Also released explicitly from [GameScreen.dispose]. Idempotent thanks to
  /// the [_disposed] guard, so whether Flame tears the game down via the
  /// GameWidget lifecycle or the host screen calls dispose directly, the
  /// long-lived resources are released exactly once.
  @override
  void dispose() {
    _releaseResources();
    super.dispose();
  }

  /// Releases every long-lived resource owned by this game and marks the game
  /// disposed so in-flight delayed callbacks bail out. Idempotent — safe to
  /// call from both the [onRemove] lifecycle hook and an explicit [dispose].
  void _releaseResources({bool cascadeChildren = false}) {
    if (_disposed) return;
    _disposed = true;

    // Stop any further simulation / audio immediately.
    try {
      pauseEngine();
    } catch (_) {}

    // Deterministically release the resources that hold native handles —
    // the accelerometer stream and the continuous audio players.
    try {
      gameFeelSystem.dispose();
    } catch (_) {}
    try {
      inputManager.dispose();
    } catch (_) {}

    // When torn down via the onRemove lifecycle hook (GameWidget detaching),
    // Flame does not automatically cascade onRemove through children — the
    // documented pattern is to do it here. When torn down via dispose(),
    // super.dispose() performs this cascade, so we don't duplicate it.
    if (cascadeChildren) {
      try {
        removeAll(children);
        processLifecycleEvents();
        images.clearCache();
        assets.clearCache();
      } catch (_) {}
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    _runtimeStateSyncAccumulator += dt;
    if (_runtimeStateSyncAccumulator >=
        GameConfig.runtimeStateSyncIntervalSeconds) {
      _runtimeStateSyncAccumulator = 0;
      _syncRuntimeState();
    }

    final session = ref.read(gameSessionProvider);
    final scaledDt = dt * _timeScale;

    if (_phase != GamePhase.playing) {
      // Timers drive HUD countdown rings from the same authoritative durations.
      final active = session.activePowerUps;
      for (final type in active) {
        final remaining = session.powerUpRemaining[type];
        if (remaining != null) {
          ref.read(gameSessionProvider.notifier).setPowerUpTimer(type, (remaining - scaledDt).clamp(0.0, 999.0).toDouble());
        }
      }

      super.update(dt);
      return;
    }

    // Generic gesture trigger: flick-up / double-tap fires the equipped
    // plane's signature power-up (Dart/Crane: BOOST, Glider: Magnet, Stunt: Ghost, Stealth: SlowMo)
    if (inputManager.consumeGestureAction()) {
      _handleGesturePowerUp();
    }

    // Apply slow-mo speed override (drives this frame's motion and the
    // distance it travels).
    double effectiveSpeed = _scrollSpeed;
    if (session.activePowerUps.contains(PowerUpType.slowMo)) {
      effectiveSpeed *= GameConfig.slowMoPowerUpMultiplier;
    }

    // Accumulate distance from this frame's effective speed.
    _distanceMeters += effectiveSpeed * scaledDt / 10.0; // px→meters factor

    // Scroll speed is a pure function of distance reached — the world only
    // speeds up as the player travels further, ramping in gradually instead
    // of accelerating by wall-clock time. Power-up overrides are applied next
    // frame against this updated base. Trials run at a fixed course speed.
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

    // Track run-shape metrics in both score modes. Only Classic persists these
    // values into challenge progress at finalization.
    if (mode == GameMode.classic || mode == GameMode.daily) {
      _trackChallengeProgress();
    }

    // ── Task 8: per-mode bookkeeping ───────────────────────────────────────
    _runTimeSeconds += dt;
    if (mode == GameMode.zen && _zenBounceCooldown > 0) {
      _zenBounceCooldown -= scaledDt;
    }

    // Publish a compact HUD snapshot at 10 Hz. The previous distance-modulo
    // condition could fire on several consecutive high-refresh frames and
    // rebuild the entire Flutter overlay far more often than intended.
    _hudUpdateAccumulator += dt;
    if (_hudUpdateAccumulator >= GameConfig.hudUpdateIntervalSeconds) {
      _hudUpdateAccumulator = 0;
      final notifier = ref.read(gameSessionProvider.notifier);
      notifier.updateFlightMetrics(
        distanceMeters: _distanceMeters,
        runTimeSeconds: _runTimeSeconds,
      );
    }
  }

  void _syncRuntimeState() {
    try {
      final settings = ref.read(settingsProvider);
      if (settings.controlScheme != inputManager.currentScheme) {
        inputManager.updateControlScheme(settings.controlScheme);
      }
      if ((settings.tiltSensitivity - inputManager.currentSensitivity).abs() >
          0.001) {
        inputManager.updateSensitivity(settings.tiltSensitivity);
      }
      inputManager.updateGesturePowerUp(settings.flickToUsePowerUp);
      _syncOnScreenControlsVisibility(settings);

      final save = ref.read(saveDataProvider);
      final pType = PlaneType.values[save.equippedPlaneIndex
          .clamp(0, PlaneType.values.length - 1)
          .toInt()];
      final pSkin = PaperSkin.values[save.equippedSkinIndex
          .clamp(0, PaperSkin.values.length - 1)
          .toInt()];
      final pLvl = save.getPlaneLevel(save.equippedPlaneIndex);
      if (pType != plane.planeType) plane.syncHitboxForPlaneType(pType);
      if (pSkin != plane.paperSkin) plane.syncSkin(pSkin);
      if (pLvl != plane.planeLevel) plane.syncLevel(pLvl);
    } catch (_) {}
  }

  void _trackChallengeProgress() {
    // Thermals entered: count rising edge of isInThermal
    final inThermal = plane.isInThermal;
    if (inThermal && !_wasInThermal) {
      _thermalsEnteredThisRun++;
    }
    _wasInThermal = inThermal;

    // Max combo and biome at which it was achieved
    final combo = scoringSystem.comboCount;
    if (combo > _maxComboThisRun) {
      _maxComboThisRun = combo;
      _biomeAtMaxCombo = biomeManager.currentBiome;
    }
    // Storm-specific max for the Storm combo challenge
    if (biomeManager.currentBiome == Biome.storm && combo > _maxComboInStormThisRun) {
      _maxComboInStormThisRun = combo;
    }

    // Building gaps: detect when plane threads a building gap
    try {
      for (final obs in obstacleSpawner.activeObstacles) {
        if (obs.type != ObstacleType.building) continue;
        if (obs.challengeGapCounted) continue;
        final building = obs as BuildingObstacle;
        final centerY = obs.position.y + obs.size.y * 0.5;
        final planeY = plane.position.y;
        if ((centerY - planeY).abs() < 18) {
          final planeX = plane.position.x;
          if (planeX >= building.gapLeft && planeX <= building.gapRight) {
            _buildingGapsPassedThisRun++;
            obs.challengeGapCounted = true;
          } else if (centerY > planeY + 28) {
            obs.challengeGapCounted = true;
          }
        } else if (obs.position.y > planeY + 80) {
          obs.challengeGapCounted = true;
        }
      }
    } catch (_) {}
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Mirrors the "show on-screen controls" setting onto the joystick and
  /// touch-zone visuals. Hiding them never disables input — it only stops the
  /// cosmetic overlays from being drawn.
  void _syncOnScreenControlsVisibility(SettingsModel settings) {
    joystickComponent.visible = settings.showOnScreenControls;
    touchZonesOverlay.visible = settings.showOnScreenControls;
  }

  /// Scroll speed for a given distance reached, clamped to [min, max].
  ///
  /// Because it is a pure function of meters traveled, the ramp-up is identical
  /// regardless of power-ups or frame rate — distance is the only driver.
  /// Zen ramps far more gently; trials run at a fixed course speed.
  double _scrollSpeedForDistance(double meters) {
    switch (mode) {
      case GameMode.trial:
        return trial?.scrollSpeedPxPerSec ?? GameConfig.baseScrollSpeed;
      case GameMode.zen:
        return (GameConfig.zenBaseScrollSpeed +
                GameConfig.zenScrollSpeedPerMeter * meters)
            .clamp(
                GameConfig.zenBaseScrollSpeed, GameConfig.zenMaxScrollSpeed);
      case GameMode.classic:
      case GameMode.daily:
        return (GameConfig.baseScrollSpeed +
                GameConfig.scrollSpeedPerMeter * meters)
            .clamp(GameConfig.baseScrollSpeed, GameConfig.maxScrollSpeed);
    }
  }

  void startRun() {
    // Daily Seeded Flight: one attempt per UTC day. If it's already used,
    // refuse to start — the daily screen routes here only when available.
    if (mode == GameMode.daily &&
        ref.read(saveDataProvider).dailyLastSeed == dailySeed &&
        ref.read(saveDataProvider).dailyAttemptUsed) {
      _phase = GamePhase.idle;
      return;
    }

    _scrollSpeed = _scrollSpeedForDistance(0);
    _distanceMeters = 0;
    _timeScale = 1.0;
    _coinRushShowerTimer = 0;
    _runTimeSeconds = 0;
    _hudUpdateAccumulator = 0;
    _runtimeStateSyncAccumulator = 0;
    _lastCrashCause = 'unknown';
    _zenBounceCooldown = 0;
    _phase = GamePhase.playing;
    _isReviving = false;

    // Reset challenge tracking
    _thermalsEnteredThisRun = 0;
    _wasInThermal = false;
    _maxComboThisRun = 0;
    _biomeAtMaxCombo = biomeManager.currentBiome;
    _maxComboInStormThisRun = 0;
    _buildingGapsPassedThisRun = 0;
    _powerUpUsedThisRun = false;
    _powerUpsUsedThisRun = 0;
    _craneChargesRemaining = (plane.planeType == PlaneType.crane) ? GameConfig.craneBranchCharges : 0;

    // ── Task 8: mode wiring ────────────────────────────────────────────────
    // Seed-aware RNG per system (daily → deterministic identical run; each
    // system gets its own derived generator so frame timing can't reorder
    // the shared draw sequence across devices).
    final seed = mode == GameMode.daily ? dailySeed : DateTime.now().millisecondsSinceEpoch;
    _spawnRng = math.Random(seed);
    obstacleSpawner.random = math.Random(seed + 101);
    collectibleSpawner.random = math.Random(seed + 202);
    powerUpSpawner.random = math.Random(seed + 303);

    // Spawner activity per mode: trials are fully scripted; zen keeps
    // obstacles + coins but no power-ups; classic/daily run everything.
    obstacleSpawner.spawnEnabled = mode != GameMode.trial;
    collectibleSpawner.autoSpawn = mode != GameMode.trial;
    powerUpSpawner.autoSpawn =
        mode == GameMode.classic || mode == GameMode.daily;

    // Trials: attach the course director + scripted wind.
    trialDirector?.removeFromParent();
    trialDirector = null;
    windSystem.scriptedWindows = null;
    if (mode == GameMode.trial && trial != null) {
      windSystem.scriptedWindows = trial!.windScript;
      trialDirector = TrialDirector(trial: trial!);
      world.add(trialDirector!);
    }

    // Resync control scheme at run start (ensures calibration is fresh).
    try {
      final settings = ref.read(settingsProvider);
      inputManager.updateControlScheme(settings.controlScheme);
      inputManager.updateSensitivity(settings.tiltSensitivity);
      inputManager.updateGesturePowerUp(settings.flickToUsePowerUp);
      inputManager.calibrateTilt();
      // Re-sync plane type/skin at run start in case hangar changed it
      final save = ref.read(saveDataProvider);
      final pType = PlaneType.values[save.equippedPlaneIndex.clamp(0, PlaneType.values.length - 1)];
      final pSkin = PaperSkin.values[save.equippedSkinIndex.clamp(0, PaperSkin.values.length - 1)];
      final pLvl = save.getPlaneLevel(save.equippedPlaneIndex);
      plane.syncHitboxForPlaneType(pType);
      plane.syncSkin(pSkin);
      plane.syncLevel(pLvl);

      // Crane branch brush-off charges (1 at L1/L2, 2 at L3)
      _craneChargesRemaining = (pType == PlaneType.crane)
          ? (pLvl >= 3 ? 2 : GameConfig.craneBranchCharges)
          : 0;

      // Paper Bomber starting shield charges (2 at L1/L2, 3 at L3) / Biplane L3
      if (pType == PlaneType.bomber) {
        _shieldChargesRemaining = pLvl >= 3 ? 3 : 2;
        ref.read(gameSessionProvider.notifier).activatePowerUp(PowerUpType.shield);
      } else if (pType == PlaneType.biplane && pLvl >= 3) {
        _shieldChargesRemaining = 1;
        ref.read(gameSessionProvider.notifier).activatePowerUp(PowerUpType.shield);
      } else {
        _shieldChargesRemaining = 0;
      }
    } catch (_) {}
    inputManager.reset();
    inputManager.resumeSensors();

    plane.reset();
    obstacleSpawner.reset();
    collectibleSpawner.reset();
    powerUpSpawner.reset();
    scoringSystem.reset();
    streakSystem.reset();
    biomeManager.reset(mode);
    windSystem.reset();
    gameFeelSystem.reset();

    // Zen Flight: gentle ambient pad from the first flap.
    if (mode == GameMode.zen) {
      gameFeelSystem.startZenMusic();
    } else {
      gameFeelSystem.stopZenMusic();
    }

    // Daily Seeded Flight: consuming the attempt counts from the moment the
    // run starts (even if the player quits mid-flight).
    if (mode == GameMode.daily) {
      ref.read(saveDataProvider.notifier).markDailyAttempt(seed: dailySeed);
    }

    ref.read(gameSessionProvider.notifier).startRun(mode: mode, trialId: trialId);

    final saveAtStart = ref.read(saveDataProvider);
    unawaited(
      AnalyticsService.instance.logRunStarted(
        mode: mode,
        controlScheme: inputManager.currentScheme,
        lifetimeRunNumber: saveAtStart.totalRuns + 1,
        trialId: trialId,
      ),
    );
  }

  /// Called by PlaneComponent when it hits an obstacle or falls off-screen.
  void onPlaneCrash({ObstacleType? obstacleType, ObstacleComponent? obstacle}) {
    if (_phase != GamePhase.playing) return;

    // ── Zen Flight (Task 8): there is no death — a gentle bump pushes the
    // plane aside and life goes on.
    if (mode == GameMode.zen) {
      _handleZenBounce(obstacle);
      return;
    }

    final session = ref.read(gameSessionProvider);

    // ── Precision Trial (Task 8): one hit ends the attempt.
    if (mode == GameMode.trial) {
      _lastCrashCause = obstacleType?.name ?? 'out_of_bounds';
      _phase = GamePhase.dying;
      spawnCrashFeedback(this, plane.position);
      pauseEngine();
      inputManager.pauseSensors();
      gameFeelSystem.onCrash();
      gameFeelSystem.silence();
      Future.delayed(
        Duration(milliseconds: (GameConfig.trialCrashFreezeSeconds * 1000).round()),
        () {
          if (_disposed) return;
          // Keep the crashed game paused while the results route is pushed.
          // Resuming here lets post-crash HUD/power-up updates continue and
          // can make the old canvas compete with the incoming results screen.
          _phase = GamePhase.gameOver;
          _finalizeTrial(completed: false, timedOut: false);
        },
      );
      return;
    }

    // Ghost or Turbo Dash: the plane phases straight through every obstacle.
    if (session.activePowerUps.contains(PowerUpType.ghost) ||
        session.activePowerUps.contains(PowerUpType.turboDash)) {
      plane.playGhostPhaseAnimation();
      return;
    }

    // Decoy Clones: absorb the next 2 obstacle hits.
    if (_decoyCloneCharges > 0) {
      _decoyCloneCharges--;
      plane.playGhostPhaseAnimation();
      gameFeelSystem.onShieldBreak();
      scoringSystem.onObstacleHit();
      if (_decoyCloneCharges <= 0) {
        ref.read(gameSessionProvider.notifier).deactivatePowerUp(PowerUpType.decoyClone);
      }
      return;
    }

    // Origami Crane: free brush-off against tree branches (organic)
    if (obstacleType != null &&
        obstacleType.isOrganic &&
        plane.planeType == PlaneType.crane &&
        _craneChargesRemaining > 0) {
      _craneChargesRemaining--;
      plane.playBranchBrushAnimation();
      gameFeelSystem.onShieldBreak();
      // Remove or recycle the obstacle so it doesn't immediately re-collide
      // We mark its near-miss as awarded and recycle it via spawner knowledge.
      // Simplest: let it continue but add brief ghost immunity via shield hit?
      // We give a tiny scale pulse and keep flying.
      scoringSystem.onObstacleHit(); // slight combo penalty but not crash
      return;
    }

    // Shield absorbs the hit — handles multi-hit shields (Bomber 2..3 hits).
    if (session.shieldActive || _shieldChargesRemaining > 0) {
      if (_shieldChargesRemaining > 1) {
        _shieldChargesRemaining--;
        plane.playShieldHitAnimation();
        gameFeelSystem.onShieldBreak();
        scoringSystem.onObstacleHit();
        return;
      } else {
        _shieldChargesRemaining = 0;
        ref.read(gameSessionProvider.notifier).consumeShield();
        scoringSystem.onObstacleHit();
        plane.playShieldHitAnimation();
        gameFeelSystem.onShieldBreak();
        return;
      }
    }

    _lastCrashCause = obstacleType?.name ?? 'out_of_bounds';
    _phase = GamePhase.dying;
    spawnCrashFeedback(this, plane.position);
    pauseEngine();
    inputManager.pauseSensors();
    gameFeelSystem.onCrash();
    gameFeelSystem.silence();

    // Brief freeze then transition to game over. We fire the navigation
    // (triggerGameOver) immediately after the short hit-stop so the results
    // screen starts sliding in at once; persistence (coins/high score/
    // challenges) runs in the background and can't hold up the transition —
    // this is what previously left a black/paused frame for a beat or two.
    // Guard with _disposed so a player who backs out mid-freeze doesn't run
    // finalization on a torn-down game.
    Future.delayed(GameConfig.crashSlowMoFreeze, () {
      if (_disposed) return;
      // Leave the engine paused until GameWidget is removed. Resuming the
      // crashed world allows timed power-up/HUD updates to keep firing while
      // the replacement route is animating, which can enqueue repeated route
      // work and present as a flickering game-over screen.
      _phase = GamePhase.gameOver;
      _finalizeRun(wasRevived: false);
    });
  }

  /// Called by rewarded-ad revive flow.
  void revive() {
    if (_isReviving || _phase != GamePhase.gameOver) return;
    _isReviving = true;
    _phase = GamePhase.playing;
    // Crash finalization keeps the engine paused while the results route is
    // being replaced. Resume it when an in-place revive is requested.
    resumeEngine();
    plane.revive();
    ref.read(gameSessionProvider.notifier).useRevive();
  }

  // ── Zen Flight (Task 8) ───────────────────────────────────────────────────

  /// Zen has no crash deaths — contact with an obstacle (or the world floor)
  /// softly pushes the plane away with a brief immunity window so it never
  /// rattles. Feedback: paper crease, a gentle scale pulse, no score loss.
  void _handleZenBounce(ObstacleComponent? obstacle) {
    if (_zenBounceCooldown > 0) return;
    _zenBounceCooldown = GameConfig.zenBounceCooldown;

    double pushX = GameConfig.zenBouncePushX;
    if (obstacle != null) {
      final delta = plane.position.x - obstacle.position.x;
      if (delta.abs() > 4) {
        pushX *= delta.isNegative ? -1 : 1;
      } else {
        pushX *= math.Random().nextBool() ? 1 : -1;
      }
    } else {
      // Fell off-screen: push back up into the world.
      pushX = 0;
    }

    plane.applyZenBounce(
      pushX: pushX,
      pushY: GameConfig.zenBouncePushY,
    );
    gameFeelSystem.onShieldBreak(); // soft haptic + chime, no penalty
    scoringSystem.onObstacleHit(); // tiny combo penalty, nothing else
  }

  /// Ends a Zen flight from the pause menu: records the personal best
  /// distance (a stat only — Zen never touches the coin economy), stops the
  /// ambient music and signals game over so the UI can show the summary.
  void endZenFlight() {
    if (_phase != GamePhase.playing && _phase != GamePhase.paused) return;
    gameFeelSystem.stopZenMusic();
    _phase = GamePhase.gameOver;
    pauseEngine();
    inputManager.pauseSensors();
    unawaited(
      AnalyticsService.instance.logZenCompleted(
        distanceMeters: _distanceMeters,
        durationSeconds: _runTimeSeconds,
      ),
    );
    try {
      ref.read(saveDataProvider.notifier).recordZenRun(_distanceMeters);
    } catch (_) {}
    ref.read(gameSessionProvider.notifier).endZen();
  }

  // ── Precision Trials (Task 8) ─────────────────────────────────────────────

  /// The course was flown to the end — evaluate stars and finalize.
  void onTrialComplete() {
    if (_phase != GamePhase.playing) return;
    pauseEngine();
    _phase = GamePhase.gameOver;
    gameFeelSystem.silence();
    _finalizeTrial(completed: true, timedOut: false);
  }

  /// The trial clock hit zero — the attempt fails.
  void onTrialTimeout() {
    if (_phase != GamePhase.playing) return;
    pauseEngine();
    _phase = GamePhase.gameOver;
    gameFeelSystem.silence();
    _finalizeTrial(completed: false, timedOut: true);
  }

  Future<void> _finalizeTrial({
    required bool completed,
    required bool timedOut,
  }) async {
    final director = trialDirector;
    final def = trial;
    if (director == null || def == null) return;

    final stars = completed ? director.evaluateStars() : 0;
    final coins = ref.read(gameSessionProvider).coinsThisRun;
    inputManager.pauseSensors();
    unawaited(
      AnalyticsService.instance.logTrialOutcome(
        trialId: def.id,
        completed: completed,
        timedOut: timedOut,
        stars: stars,
        durationSeconds: director.timeUsedSeconds,
        coinsCollected: coins,
        totalCoins: def.countCoins(),
      ),
    );

    // Compute the new-best flag synchronously from the in-memory save so the
    // results screen can celebrate without waiting for disk. The matching
    // write to storage happens in the background.
    final previousBest =
        ref.read(saveDataProvider.notifier).trialBestStars(def.id);
    final isNewBestStars = stars > previousBest;

    // Navigate to results immediately so the player never sees a frozen/black
    // frame. Persisting the best-star record happens in the background.
    if (!_disposed) {
      ref.read(gameSessionProvider.notifier).completeTrial(
        TrialOutcome(
          trialId: def.id,
          completed: completed,
          timedOut: timedOut,
          stars: stars,
          timeUsedSeconds: director.timeUsedSeconds,
          coinsCollected: coins,
          totalCoins: def.countCoins(),
          isNewBestStars: isNewBestStars,
        ),
      );
    }

    if (stars > 0) {
      unawaited(() async {
        try {
          await ref
              .read(saveDataProvider.notifier)
              .recordTrialStars(trialId: def.id, stars: stars);
        } catch (_) {}
      }());
    }
  }

  /// Ends an in-progress run without awarding economy/progression and records
  /// the missing half of the death-rate funnel (players who quit before a
  /// crash). Safe to call from widget disposal.
  void abandonRun({required String reason}) {
    if (_phase != GamePhase.playing && _phase != GamePhase.paused) return;
    final session = ref.read(gameSessionProvider);
    unawaited(
      AnalyticsService.instance.logRunAbandoned(
        mode: mode,
        distanceMeters: _distanceMeters,
        durationSeconds: _runTimeSeconds,
        score: session.score,
        reason: reason,
      ),
    );
    _phase = GamePhase.idle;
    inputManager.pauseSensors();
    gameFeelSystem.silence();
    try {
      pauseEngine();
    } catch (_) {}
  }

  void pauseRun() {
    if (_phase != GamePhase.playing) return;
    _phase = GamePhase.paused;
    pauseEngine();
    inputManager.pauseSensors();
    gameFeelSystem.silence();
    ref.read(gameSessionProvider.notifier).pause();
  }

  void resumeRun() {
    if (_phase != GamePhase.paused) return;
    _phase = GamePhase.playing;
    inputManager.resumeSensors();
    inputManager.calibrateTilt();
    resumeEngine();
    ref.read(gameSessionProvider.notifier).resume();
  }

  void applySlowMo(double duration) {
    _timeScale = GameConfig.slowMoPowerUpMultiplier;
    Future.delayed(Duration(milliseconds: (duration * 1000).toInt()), () {
      if (_disposed) return;
      _timeScale = 1.0;
      ref.read(gameSessionProvider.notifier).deactivatePowerUp(PowerUpType.slowMo);
    });
  }

  /// Death Defying near-miss reward: a micro hit-stop freeze-frame followed by
  /// a quick camera zoom pulse — the "did I just survive that?" beat.
  ///
  /// Uses [pauseEngine]/[resumeEngine] (like the crash freeze) so the whole
  /// world halts for ~110ms, then the zoom pulse plays out over real time.
  /// Guarded so repeat awards can't stack freezes, and a player pause during
  /// the window cancels the resume.
  void triggerDeathDefyingSlowMo() {
    if (_phase != GamePhase.playing || _deathDefyingFreezeActive) return;
    _deathDefyingFreezeActive = true;
    pauseEngine();
    Future.delayed(GameConfig.deathDefyingFreeze, () {
      if (_disposed) return;
      if (_phase == GamePhase.playing) {
        resumeEngine();
        // ScaleEffect on the viewfinder drives the camera zoom (Flame's
        // documented camera-zoom mechanism); uniform scale asserted by API.
        camera.viewfinder.add(
          ScaleEffect.to(
            Vector2.all(GameConfig.deathDefyingCameraZoom),
            EffectController(duration: 0.08, reverseDuration: 0.16),
          ),
        );
      }
      _deathDefyingFreezeActive = false;
    });
  }

  /// Kicks off the Coin Rush power-up: immediately rains an opening coin shower
  /// and resets the periodic-shower timer.
  void beginCoinRush() {
    _coinRushShowerTimer = 0;
    collectibleSpawner.spawnCoinShower();
  }

  /// Applies a timed/charge power-up effect. Shared by on-world pickups
  /// ([PowerUpComponent]) and gesture-triggered plane power-ups so both paths
  /// behave identically.
  void applyPowerUp(PowerUpType type) {
    // Track for challenge "without power-up" and "use power-ups"
    _powerUpUsedThisRun = true;
    _powerUpsUsedThisRun++;

    final notifier = ref.read(gameSessionProvider.notifier);
    switch (type) {
      case PowerUpType.shield:
        // Absorbs hits — no timer; consumed on impact.
        notifier.activatePowerUp(PowerUpType.shield);
        _shieldChargesRemaining = math.max(_shieldChargesRemaining, 1);
      case PowerUpType.magnet:
        notifier.activatePowerUp(PowerUpType.magnet);
        notifier.setPowerUpTimer(PowerUpType.magnet, GameConfig.magnetDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.magnetDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.magnet);
          },
        );
      case PowerUpType.ghost:
        // Phase through every obstacle + chromatic aberration entry!
        notifier.activatePowerUp(PowerUpType.ghost);
        notifier.setPowerUpTimer(PowerUpType.ghost, GameConfig.ghostDuration);
        gameFeelSystem.onGhostActivated();
        Future.delayed(
          Duration(milliseconds: (GameConfig.ghostDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.ghost);
          },
        );
      case PowerUpType.slowMo:
        notifier.activatePowerUp(PowerUpType.slowMo);
        notifier.setPowerUpTimer(PowerUpType.slowMo, GameConfig.slowMoDuration);
        applySlowMo(GameConfig.slowMoDuration);
      case PowerUpType.coinRush:
        // 2× coin value for the duration, plus an immediate coin shower.
        notifier.activatePowerUp(PowerUpType.coinRush);
        notifier.setPowerUpTimer(PowerUpType.coinRush, GameConfig.coinRushDuration);
        beginCoinRush();
        Future.delayed(
          Duration(milliseconds: (GameConfig.coinRushDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.coinRush);
          },
        );
      case PowerUpType.doubleScore:
        notifier.activatePowerUp(PowerUpType.doubleScore);
        notifier.setPowerUpTimer(PowerUpType.doubleScore, GameConfig.doubleScoreDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.doubleScoreDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.doubleScore);
          },
        );
      case PowerUpType.shrink:
        notifier.activatePowerUp(PowerUpType.shrink);
        notifier.setPowerUpTimer(PowerUpType.shrink, GameConfig.shrinkDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.shrinkDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.shrink);
          },
        );
      case PowerUpType.windCaller:
        notifier.activatePowerUp(PowerUpType.windCaller);
        notifier.setPowerUpTimer(PowerUpType.windCaller, GameConfig.windCallerDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.windCallerDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.windCaller);
          },
        );
      case PowerUpType.decoyClone:
        _decoyCloneCharges = 2;
        notifier.activatePowerUp(PowerUpType.decoyClone);
      case PowerUpType.blackHole:
        notifier.activatePowerUp(PowerUpType.blackHole);
        notifier.setPowerUpTimer(PowerUpType.blackHole, GameConfig.blackHoleDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.blackHoleDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.blackHole);
          },
        );
      case PowerUpType.turboDash:
        notifier.activatePowerUp(PowerUpType.turboDash);
        notifier.setPowerUpTimer(PowerUpType.turboDash, GameConfig.turboDashDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.turboDashDuration * 1000).toInt()),
          () {
            if (!_disposed) notifier.deactivatePowerUp(PowerUpType.turboDash);
          },
        );
    }
  }

  /// Fires the equipped plane's signature power-up from the flick-up /
  /// double-tap gesture.
  ///
  /// The gesture is generic — each plane activates its own action:
  ///   • Paper Dart / Crane → BOOST paper-snap burst (charge-based)
  ///   • Glider Fold   → Magnet (coin pull)
  ///   • Stunt Fold    → Ghost (phase through obstacles)
  ///   • Stealth Jet   → SlowMo
  /// Respects the "flick to use power-up" setting.
  void _handleGesturePowerUp() {
    final settings = ref.read(settingsProvider);
    if (!settings.flickToUsePowerUp) return;

    final save = ref.read(saveDataProvider);
    final planeType = PlaneType.values[save.equippedPlaneIndex.clamp(0, PlaneType.values.length - 1)];

    // Dart/Crane's signature action is the charge-based paper-snap burst —
    // the only power-up allowed in Zen Flight (no timed abilities there).
    if (planeType.usesBoostAsSignatureAction) {
      inputManager.requestSnapFromButton();
      return;
    }

    // Zen + Trials: timed power-ups stay out — Zen is pure gliding and
    // trials are pure skill (a ghost would trivialise the courses).
    if (mode == GameMode.zen || mode == GameMode.trial) return;

    final type = planeType.signaturePowerUp;
    final session = ref.read(gameSessionProvider);
    if (session.activePowerUps.contains(type)) {
      // Already running — no-op so repeated flicks can't stack timers.
      return;
    }

    spawnPowerUpFeedback(this, plane.position, type);
    applyPowerUp(type);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _finalizeRun({required bool wasRevived}) async {
    final session = ref.read(gameSessionProvider);

    // Compute the high-score flag synchronously from the in-memory save (the
    // authoritative pre-run high score) so the results screen can show the
    // NEW BEST stamp without waiting for disk. The matching write to storage
    // happens in the background below.
    final preRunSave = ref.read(saveDataProvider);
    final isNewHighScore =
        mode != GameMode.daily && session.score > preRunSave.highScore;

    final result = RunResult(
      score: session.score,
      distanceMeters: _distanceMeters,
      coinsCollected: session.coinsThisRun,
      nearMisses: session.nearMissesThisRun,
      isNewHighScore: isNewHighScore,
      finalBiome: session.currentBiome,
      wasRevived: wasRevived,
      runDurationSeconds: _runTimeSeconds,
      crashCause: _lastCrashCause,
      maxCombo: _maxComboThisRun,
      powerUpsUsed: _powerUpsUsedThisRun,
      lifetimeRunNumber: preRunSave.totalRuns + 1,
      runsSinceLastInterstitial:
          preRunSave.runsSinceLastInterstitial + 1,
    );

    // Trigger the game-over transition immediately so the results screen starts
    // sliding in at once. Persistence (coins, high score, challenges, the
    // daily leaderboard) is fire-and-forget below so it can never add latency
    // — or a black/paused frame — between the crash and the results screen.
    if (!_disposed) {
      ref.read(gameSessionProvider.notifier).triggerGameOver(result);
    }

    // Persist in the background (unawaited).
    unawaited(_persistRun());
  }

  /// Writes the finished run's results to storage off the critical path.
  Future<void> _persistRun() async {
    if (_disposed) return;
    final session = ref.read(gameSessionProvider);
    final notifier = ref.read(saveDataProvider.notifier);

    try {
      if (mode == GameMode.daily) {
        // ── Daily Seeded Flight: the award is the leaderboard — the run never
        // touches coins, high scores or challenge objectives.
        try {
          await DailyLeaderboard.instance.submitScore(
            seed: dailySeed,
            score: session.score,
            distanceMeters: _distanceMeters,
          );
        } catch (_) {}
        return;
      }

      // Classic: full economy + challenge integration.
      await notifier.recordRunResult(
        score: session.score,
        distanceMeters: _distanceMeters,
        coinsEarned: session.coinsThisRun,
        nearMisses: session.nearMissesThisRun,
      );

      try {
        await notifier.updateChallengesForRun(
          thermalsEntered: _thermalsEnteredThisRun,
          maxCombo: _maxComboThisRun,
          biomeForMaxCombo: _biomeAtMaxCombo,
          maxComboInStorm: _maxComboInStormThisRun,
          buildingGapsPassed: _buildingGapsPassedThisRun,
          usedPowerUp: _powerUpUsedThisRun,
          coinsCollected: session.coinsThisRun,
          nearMisses: session.nearMissesThisRun,
          distanceMeters: _distanceMeters,
          powerUpsUsed: _powerUpsUsedThisRun,
        );
      } catch (_) {}
    } catch (_) {
      // Persistence must never crash the post-game flow.
    }
  }

  // ── Input passthrough (FlameGame tap/drag → InputManager) ─────────────────

  @override
  void onTapDown(TapDownEvent event) {
    inputManager.onTapDown(event.canvasPosition);
  }

  @override
  void onTapUp(TapUpEvent event) {
    inputManager.onTapUp(event.canvasPosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    inputManager.onDragStart(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // Flame 1.38+ renamed DragUpdateEvent.canvasPosition -> canvasEndPosition /
    // canvasStartPosition (see flame changelog 1.11 migration). Use
    // canvasEndPosition for current flame; fallback to canvasPosition via
    // dynamic for older cached builds.
    final pos = event.canvasEndPosition;
    inputManager.onDragUpdate(pos);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    inputManager.onDragEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    inputManager.onDragCancel();
  }

  /// Called by HUD BOOST button.
  bool triggerSnapBoost() => inputManager.requestSnapFromButton();
}
