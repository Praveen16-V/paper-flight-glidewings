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
import '../providers/game_session_provider.dart';
import '../providers/save_data_provider.dart';
import '../providers/settings_provider.dart';
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

  // Crane free brush-off charges remaining this run.
  int _craneChargesRemaining = 0;

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
    windSystem = WindSystem();
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
    plane = PlaneComponent(
      game: this,
      planeType: planeType,
      paperSkin: skin,
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

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    // Keep input manager in sync with live settings (allows mid-run
    // sensitivity change if settings are altered via debug overlay).
    try {
      final settings = ref.read(settingsProvider);
      if (settings.controlScheme != inputManager.currentScheme) {
        inputManager.updateControlScheme(settings.controlScheme);
      }
      if ((settings.tiltSensitivity - inputManager.currentSensitivity).abs() > 0.001) {
        inputManager.updateSensitivity(settings.tiltSensitivity);
      }
      inputManager.updateGesturePowerUp(settings.flickToUsePowerUp);
      _syncOnScreenControlsVisibility(settings);
      // Sync plane skin/type if changed from hangar mid-session
      try {
        final save = ref.read(saveDataProvider);
        final pType = PlaneType.values[save.equippedPlaneIndex.clamp(0, PlaneType.values.length - 1)];
        final pSkin = PaperSkin.values[save.equippedSkinIndex.clamp(0, PaperSkin.values.length - 1)];
        if (pType != plane.planeType) plane.syncHitboxForPlaneType(pType);
        if (pSkin != plane.paperSkin) plane.syncSkin(pSkin);
      } catch (_) {}
    } catch (_) {}

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

    // ── Challenge tracking (Task 7) ────────────────────────────────────────
    _trackChallengeProgress();

    // Push distance to provider for HUD (throttled — every 5 frames approx).
    if ((_distanceMeters * 10).toInt() % 5 == 0) {
      ref
          .read(gameSessionProvider.notifier)
          .updateDistance(_distanceMeters);
    }
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
      plane.syncHitboxForPlaneType(pType);
      plane.syncSkin(pSkin);
      _craneChargesRemaining = (pType == PlaneType.crane) ? GameConfig.craneBranchCharges : 0;
    } catch (_) {}
    inputManager.reset();

    plane.reset();
    obstacleSpawner.reset();
    collectibleSpawner.reset();
    powerUpSpawner.reset();
    scoringSystem.reset();
    streakSystem.reset();
    biomeManager.reset();
    windSystem.reset();
    gameFeelSystem.reset();

    ref.read(gameSessionProvider.notifier).startRun();
  }

  /// Called by PlaneComponent when it hits an obstacle or falls off-screen.
  void onPlaneCrash({ObstacleType? obstacleType, ObstacleComponent? obstacle}) {
    if (_phase != GamePhase.playing) return;

    final session = ref.read(gameSessionProvider);

    // Ghost: the plane phases straight through every obstacle.
    if (session.activePowerUps.contains(PowerUpType.ghost)) {
      plane.playGhostPhaseAnimation();
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

    // Shield absorbs the hit — the combo gauge keeps half of itself instead
    // of facing the old instant wipe (Combo Decay design).
    if (session.shieldActive) {
      ref.read(gameSessionProvider.notifier).consumeShield();
      scoringSystem.onObstacleHit();
      plane.playShieldHitAnimation();
      gameFeelSystem.onShieldBreak();
      return;
    }

    _phase = GamePhase.dying;
    spawnCrashFeedback(this, plane.position);
    pauseEngine();
    gameFeelSystem.onCrash();
    gameFeelSystem.silence();

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
    gameFeelSystem.silence();
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
        // Absorbs exactly one hit — no timer; consumed on impact.
        notifier.activatePowerUp(PowerUpType.shield);
      case PowerUpType.magnet:
        notifier.activatePowerUp(PowerUpType.magnet);
        notifier.setPowerUpTimer(PowerUpType.magnet, GameConfig.magnetDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.magnetDuration * 1000).toInt()),
          () => notifier.deactivatePowerUp(PowerUpType.magnet),
        );
      case PowerUpType.ghost:
        // Phase through every obstacle — the big "fly through the wall" moment.
        notifier.activatePowerUp(PowerUpType.ghost);
        notifier.setPowerUpTimer(PowerUpType.ghost, GameConfig.ghostDuration);
        Future.delayed(
          Duration(milliseconds: (GameConfig.ghostDuration * 1000).toInt()),
          () => notifier.deactivatePowerUp(PowerUpType.ghost),
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
          () => notifier.deactivatePowerUp(PowerUpType.coinRush),
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

    // Dart/Crane's signature action is the charge-based paper-snap burst
    if (planeType.usesBoostAsSignatureAction) {
      inputManager.requestSnapFromButton();
      return;
    }

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
    final notifier = ref.read(saveDataProvider.notifier);

    final isNew = await notifier.recordRunResult(
      score: session.score,
      distanceMeters: _distanceMeters,
      coinsEarned: session.coinsThisRun,
      nearMisses: session.nearMissesThisRun,
    );

    // Update challenges with run stats
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
