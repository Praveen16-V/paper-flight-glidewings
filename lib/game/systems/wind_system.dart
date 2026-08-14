import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/noise.dart';
import '../../models/trial_definition.dart';
import '../paper_flight_game.dart';

class LaneWind {
  const LaneWind({
    required this.lateralForce,
    required this.liftBonus,
    required this.type,
    required this.intensity,
  });

  final double lateralForce;
  final double liftBonus;
  final WindType type;
  final double intensity;
}

/// The resolved influence of one or more micro-biome turbulence cells at the
/// plane's current horizontal position.
class TurbulenceSample {
  const TurbulenceSample({
    required this.lateralForce,
    required this.controlMultiplier,
    required this.intensity,
  });

  /// Signed lateral gust to add to the lane wind, in px/s.
  final double lateralForce;

  /// Fraction of normal steering authority left inside the cell.
  final double controlMultiplier;

  /// Visual/gameplay intensity after spatial falloff (0..1).
  final double intensity;
}

/// Read-only visual description of a local, rapidly shifting weather cell.
///
/// The cell is deliberately a horizontal pocket rather than a full wind lane:
/// players can spot its swirls, fly around it, or actively correct through it.
/// [lateralForce] is signed and changes several times per second.
class TurbulencePocket {
  const TurbulencePocket({
    required this.normX,
    required this.radius,
    required this.ttl,
    double? duration,
    this.intensity = GameConfig.turbulencePocketMinIntensity,
    this.lateralForce = 0.0,
    this.shiftFrequency = GameConfig.turbulencePocketMinShiftHz,
    this.sourceObstacle,
  }) : duration = duration ?? ttl;

  /// Centre of the cell as a fraction of design width.
  final double normX;

  /// Horizontal radius as a fraction of design width.
  final double radius;

  /// Seconds still remaining before the cell dissipates.
  final double ttl;

  /// Original lifespan, used to fade the visual in/out gracefully.
  final double duration;

  /// Base cell strength before horizontal falloff.
  final double intensity;

  /// Current signed, rapidly changing lateral gust in px/s.
  final double lateralForce;

  /// Number of direction cycles per second.
  final double shiftFrequency;

  /// The obstacle event that seeded this cell, if it was naturally spawned.
  final ObstacleType? sourceObstacle;

  double get lifeFraction => duration <= 0
      ? 0.0
      : (ttl / duration).clamp(0.0, 1.0).toDouble();

  bool contains(double testNormX) => (testNormX - normX).abs() < radius;
}

/// Four evolving wind lanes plus local micro-biome turbulence cells. Rendering
/// and flight physics read the same cell data, so every visible gust is real.
///
/// Task 8:
///  - [WindSystem.seed] makes the noise field + turbulence deterministic —
///    the Daily Seeded Flight passes the daily seed so every player faces the
///    identical wind.
///  - [WindSystem.scriptedWindows] overrides the noise field for Precision
///    Trials (handcrafted thermal / turbulence lanes).
///  - Zen Flight scales the whole field down via [GameConfig.zenWindScale]
///    and never naturally spawns turbulence.
class WindSystem extends Component with HasGameRef<PaperFlightGame> {
  WindSystem({int? seed})
      : _noise = ValueNoise(seed: seed ?? 7),
        _rng = math.Random(seed ?? 7);

  final ValueNoise _noise;
  final math.Random _rng;
  double _time = 0;
  double _turbulenceSpawnCooldown = 0;
  final List<_TurbulencePocketState> _pockets = [];

  /// Scripted wind lane windows for Precision Trials (null = natural noise).
  List<ScriptedWindWindow>? scriptedWindows;

  List<TurbulencePocket> get turbulencePockets => _pockets
      .map((p) => p.snapshot)
      .toList(growable: false);

  @override
  void update(double dt) {
    // Only while playing: keeps the seeded RNG draw sequence identical for
    // every daily run (idle time before the run must not consume draws).
    if (gameRef.phase != GamePhase.playing) return;

    _time += dt * GameConfig.windNoiseTimeScale;
    _turbulenceSpawnCooldown =
        math.max(0.0, _turbulenceSpawnCooldown - dt).toDouble();

    for (final pocket in _pockets) {
      pocket.advance(dt);
    }
    _pockets.removeWhere((pocket) => pocket.ttl <= 0);
  }

  LaneWind windAt(int laneIndex) {
    final profile = this.profile;

    // Precision Trial wind is fully handcrafted — windows win over noise.
    final windows = scriptedWindows;
    if (windows != null) {
      for (final w in windows) {
        if (w.laneIndex == laneIndex &&
            gameRef.distanceMeters >= w.startMeters &&
            gameRef.distanceMeters < w.endMeters) {
          return _scriptedLaneWind(w, profile);
        }
      }
      // Outside any window the air is still — trials only push where scripted.
      return const LaneWind(
        lateralForce: 0,
        liftBonus: 0,
        type: WindType.calm,
        intensity: 0,
      );
    }

    try {
      if (gameRef.powerUpState.windCallerActive) {
        // Wind Caller power-up: disables adverse wind lanes, creates calm
        // updrafts, and also suppresses pocket samples in [turbulenceAt].
        return const LaneWind(
          lateralForce: 0,
          liftBonus: 80.0,
          type: WindType.thermal,
          intensity: 0.6,
        );
      }
    } catch (_) {}

    final noiseVal = _noise.fbm(
      laneIndex * GameConfig.windNoiseLaneScale,
      _time,
      octaves: 3,
    );
    WindType type;
    double lateral;
    double lift = 0;
    if (noiseVal > .65) {
      type = WindType.thermal;
      lateral = noiseVal * GameConfig.maxWindForce * .3 * profile.wind;
      lift = GameConfig.thermalLiftForce *
          (noiseVal - .65) /
          .35 *
          profile.thermal;
    } else if (noiseVal > .25) {
      type = WindType.rightPush;
      lateral = noiseVal * GameConfig.maxWindForce * profile.wind;
    } else if (noiseVal < -.25) {
      type = WindType.leftPush;
      lateral = noiseVal * GameConfig.maxWindForce * profile.wind;
    } else {
      type = WindType.calm;
      lateral = noiseVal * GameConfig.maxWindForce * .2 * profile.wind;
    }

    final zenScale = gameRef.mode == GameMode.zen
        ? GameConfig.zenWindScale
        : 1.0;
    return LaneWind(
      lateralForce: lateral * zenScale,
      liftBonus: lift * zenScale,
      type: type,
      intensity: (noiseVal.abs() * profile.wind).clamp(0.0, 1.0).toDouble(),
    );
  }

  LaneWind _scriptedLaneWind(ScriptedWindWindow w, AirProfile profile) {
    switch (w.type) {
      case WindType.calm:
        return const LaneWind(
          lateralForce: 0,
          liftBonus: 0,
          type: WindType.calm,
          intensity: 0,
        );
      case WindType.leftPush:
        return LaneWind(
          lateralForce: -GameConfig.maxWindForce * profile.wind * w.intensity,
          liftBonus: 0,
          type: WindType.leftPush,
          intensity: w.intensity,
        );
      case WindType.rightPush:
        return LaneWind(
          lateralForce: GameConfig.maxWindForce * profile.wind * w.intensity,
          liftBonus: 0,
          type: WindType.rightPush,
          intensity: w.intensity,
        );
      case WindType.thermal:
        return LaneWind(
          lateralForce: 0,
          liftBonus: GameConfig.thermalLiftForce *
              profile.thermal *
              w.intensity,
          type: WindType.thermal,
          intensity: w.intensity,
        );
      case WindType.turbulent:
        // Deterministic jitter from the seeded noise field.
        final jitter = _noise.fbm(w.laneIndex * 3.7, _time, octaves: 2);
        return LaneWind(
          lateralForce:
              jitter * GameConfig.maxWindForce * profile.wind * w.intensity,
          liftBonus: 0,
          type: WindType.turbulent,
          intensity: w.intensity,
        );
    }
  }

  int laneForNormX(double normX) =>
      (normX * GameConfig.windLaneCount)
          .floor()
          .clamp(0, GameConfig.windLaneCount - 1)
          .toInt();

  /// Returns the signed lateral force at a design-space [x] coordinate.
  ///
  /// This composes the broad lane push with any local turbulence cell, so
  /// visuals such as wing flex can react to the exact same air the plane feels.
  double currentForceAt(double x) {
    final normX = (x / GameConfig.designWidth).clamp(0.0, 1.0).toDouble();
    final laneForce = windAt(laneForNormX(normX)).lateralForce;
    final pocketForce = turbulenceAt(normX)?.lateralForce ?? 0.0;
    return laneForce + pocketForce;
  }

  /// Samples the local cells at [normX]. A null result means normal lane wind
  /// is sufficient. Wind Caller deliberately calms both lane and pocket gusts.
  TurbulenceSample? turbulenceAt(double normX) {
    if (_pockets.isEmpty || _isWindCallerActive) return null;

    var totalLateralForce = 0.0;
    var strongestInfluence = 0.0;
    var accumulatedIntensity = 0.0;
    final zenScale = gameRef.mode == GameMode.zen
        ? GameConfig.zenWindScale
        : 1.0;

    for (final pocket in _pockets) {
      final influence = pocket.influenceAt(normX);
      if (influence <= 0) continue;

      totalLateralForce +=
          pocket.currentLateralForce * influence * profile.wind * zenScale;
      strongestInfluence =
          math.max(strongestInfluence, influence).toDouble();
      accumulatedIntensity += pocket.intensity * influence;
    }

    if (strongestInfluence <= 0) return null;

    // A rare overlap should feel busy, not become an unavoidable side launch.
    final cap = GameConfig.maxWindForce * profile.wind * 1.15;
    return TurbulenceSample(
      lateralForce: totalLateralForce.clamp(-cap, cap).toDouble(),
      controlMultiplier: (1.0 -
              GameConfig.turbulenceControlReduction * strongestInfluence)
          .clamp(0.0, 1.0)
          .toDouble(),
      intensity: accumulatedIntensity.clamp(0.0, 1.0).toDouble(),
    );
  }

  bool isInTurbulence(double normX) => turbulenceAt(normX) != null;

  List<double> get laneIntensities =>
      List.generate(GameConfig.windLaneCount, (i) => windAt(i).intensity);

  /// Adds a scripted turbulence pocket (Precision Trials) or a custom cell.
  /// Natural obstacle-seeded cells use the same API, but randomize their
  /// duration, intensity and direction-shift rate within [GameConfig].
  bool addTurbulencePocket(
    double normX,
    double radius,
    double ttl, {
    double? intensity,
    double? shiftFrequency,
    ObstacleType? sourceObstacle,
  }) {
    if (_pockets.length >= GameConfig.turbulencePocketMaxActive) return false;
    if (ttl <= 0 || radius <= 0) return false;

    _pockets.add(
      _TurbulencePocketState(
        normX: normX.clamp(0.05, 0.95).toDouble(),
        radius: radius.clamp(0.04, 0.30).toDouble(),
        duration: ttl,
        intensity: (intensity ?? GameConfig.turbulencePocketMinIntensity)
            .clamp(0.05, 1.0)
            .toDouble(),
        shiftFrequency:
            (shiftFrequency ?? GameConfig.turbulencePocketMinShiftHz)
                .clamp(0.2, 6.0)
                .toDouble(),
        phase: _rng.nextDouble() * math.pi * 2,
        sourceObstacle: sourceObstacle,
      ),
    );
    return true;
  }

  /// Called by the obstacle spawner after a procedural obstacle is placed. A cell
  /// is seeded near that obstacle instead of by an unrelated timer, making the
  /// weather read as a small local biome and keeping Daily runs deterministic.
  bool spawnTurbulenceAlongsideObstacle({
    required double anchorX,
    required double safeCorridorX,
    required ObstacleType obstacleType,
  }) {
    if (gameRef.mode == GameMode.zen || gameRef.mode == GameMode.trial) {
      return false;
    }
    if (_pockets.length >= GameConfig.turbulencePocketMaxActive ||
        _turbulenceSpawnCooldown > 0) {
      return false;
    }

    final chance = _spawnChanceFor(obstacleType);
    if (_rng.nextDouble() > chance) return false;

    final radius = _randomRange(
      GameConfig.turbulencePocketMinRadius,
      GameConfig.turbulencePocketMaxRadius,
    );
    final anchorNorm =
        (anchorX / GameConfig.designWidth).clamp(0.0, 1.0).toDouble();
    final safeNorm =
        (safeCorridorX / GameConfig.designWidth).clamp(0.0, 1.0).toDouble();
    final direction = _rng.nextBool() ? -1.0 : 1.0;
    final offset = _randomRange(0.08, 0.20);
    var pocketNorm = anchorNorm + direction * offset;

    // Keep the core slightly off the already planned safe corridor. It is still
    // close enough to require a correction, but never turns a fair obstacle
    // gap into a fully wind-blocked wall.
    if ((pocketNorm - safeNorm).abs() < radius * 0.55) {
      final saferSide = pocketNorm < safeNorm ? -1.0 : 1.0;
      pocketNorm = safeNorm + saferSide * (radius * 0.75 + offset * 0.5);
    }
    pocketNorm = pocketNorm.clamp(radius + 0.02, 0.98 - radius).toDouble();

    final spawned = addTurbulencePocket(
      pocketNorm,
      radius,
      _randomRange(
        GameConfig.turbulencePocketMinDuration,
        GameConfig.turbulencePocketMaxDuration,
      ),
      intensity: _randomRange(
        GameConfig.turbulencePocketMinIntensity,
        GameConfig.turbulencePocketMaxIntensity,
      ),
      shiftFrequency: _randomRange(
        GameConfig.turbulencePocketMinShiftHz,
        GameConfig.turbulencePocketMaxShiftHz,
      ),
      sourceObstacle: obstacleType,
    );
    if (spawned) {
      _turbulenceSpawnCooldown = GameConfig.turbulencePocketSpawnCooldown;
    }
    return spawned;
  }

  double _spawnChanceFor(ObstacleType obstacleType) {
    final base = gameRef.biomeManager.currentBiome == Biome.storm
        ? GameConfig.turbulencePocketStormSpawnChance
        : GameConfig.turbulencePocketBaseSpawnChance;
    final modifier = switch (obstacleType) {
      ObstacleType.stormCloud => 1.25,
      ObstacleType.windTurbine ||
      ObstacleType.kite ||
      ObstacleType.weatherBalloon ||
      ObstacleType.windsock => 1.08,
      // Gates already demand precise placement, so pair them with a cell less
      // often while still allowing occasional compound-weather moments.
      ObstacleType.powerLine ||
      ObstacleType.building ||
      ObstacleType.clothesline => 0.42,
      _ => 0.82,
    };
    return (base * modifier).clamp(0.0, 0.92).toDouble();
  }

  double _randomRange(double min, double max) =>
      min + _rng.nextDouble() * (max - min);

  /// True while Wind Caller is calming natural lane and pocket weather.
  bool get windCallerActive => _isWindCallerActive;

  bool get _isWindCallerActive {
    try {
      return gameRef.powerUpState.windCallerActive;
    } catch (_) {
      return false;
    }
  }

  /// Lets plane mechanics tune gravity/control response without duplicating
  /// biome decisions in individual components.
  AirProfile get profile {
    switch (gameRef.biomeManager.currentBiome) {
      case Biome.backyard:
        return const AirProfile(wind: .55, thermal: .65, gravity: 1, control: 1.08);
      case Biome.city:
        return const AirProfile(wind: 1.25, thermal: 1.25, gravity: 1, control: .94);
      case Biome.storm:
        return const AirProfile(wind: 1.65, thermal: .85, gravity: 1.08, control: .76);
      case Biome.mountain:
        return const AirProfile(wind: 1.15, thermal: 1.7, gravity: .94, control: .9);
      case Biome.night:
        return const AirProfile(wind: .78, thermal: .85, gravity: 1, control: 1);
      case Biome.ocean:
        return const AirProfile(wind: 1.05, thermal: .72, gravity: .96, control: .92);
      case Biome.atmosphere:
        return const AirProfile(wind: .72, thermal: .5, gravity: .58, control: 1.04);
    }
  }

  void reset() {
    _time = 0;
    _turbulenceSpawnCooldown = 0;
    _pockets.clear();
  }
}

class AirProfile {
  const AirProfile({
    required this.wind,
    required this.thermal,
    required this.gravity,
    required this.control,
  });

  final double wind;
  final double thermal;
  final double gravity;
  final double control;
}

class _TurbulencePocketState {
  _TurbulencePocketState({
    required this.normX,
    required this.radius,
    required this.duration,
    required this.intensity,
    required this.shiftFrequency,
    required this.phase,
    this.sourceObstacle,
  }) : ttl = duration;

  final double normX;
  final double radius;
  final double duration;
  final double intensity;
  final double shiftFrequency;
  final double phase;
  final ObstacleType? sourceObstacle;

  double ttl;
  double _age = 0;

  void advance(double dt) {
    ttl -= dt;
    _age += dt;
  }

  /// Smooth but rapidly reversing gusts. The secondary wave prevents a cell
  /// from feeling like a perfectly predictable sine wave while remaining fully
  /// deterministic for Daily Flight.
  double get currentLateralForce {
    final primaryPhase = _age * shiftFrequency * math.pi * 2 + phase;
    final primary = math.sin(primaryPhase);
    final secondary = math.sin(primaryPhase * 2.17 + phase * 1.61) * 0.30;
    final normalized = (primary + secondary).clamp(-1.0, 1.0).toDouble();
    return normalized * GameConfig.maxWindForce * intensity;
  }

  double influenceAt(double testNormX) {
    final normalizedDistance = (testNormX - normX).abs() / radius;
    if (normalizedDistance >= 1.0) return 0.0;
    final edge = 1.0 - normalizedDistance;
    // Cubic smoothstep gives a calm, readable boundary instead of a hard wall.
    return edge * edge * (3.0 - 2.0 * edge);
  }

  TurbulencePocket get snapshot => TurbulencePocket(
        normX: normX,
        radius: radius,
        ttl: ttl.clamp(0.0, duration).toDouble(),
        duration: duration,
        intensity: intensity,
        lateralForce: currentLateralForce,
        shiftFrequency: shiftFrequency,
        sourceObstacle: sourceObstacle,
      );
}
