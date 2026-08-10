import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/noise.dart';
import '../../models/trial_definition.dart';
import '../../providers/game_session_provider.dart';
import '../paper_flight_game.dart';

class LaneWind {
  const LaneWind({required this.lateralForce, required this.liftBonus, required this.type, required this.intensity});
  final double lateralForce;
  final double liftBonus;
  final WindType type;
  final double intensity;
}

/// Read-only visual description of a sluggish, swirling patch of air.
class TurbulencePocket {
  const TurbulencePocket({required this.normX, required this.radius, required this.ttl});
  final double normX;
  final double radius;
  final double ttl;
}

/// Four evolving wind lanes, with biome-specific force profiles and temporary
/// turbulence pockets. Rendering reads the same data the plane physics uses.
///
/// Task 8:
///  - [WindSystem.seed] makes the noise field + turbulence deterministic —
///    the Daily Seeded Flight passes the daily seed so every player faces the
///    identical wind.
///  - [WindSystem.scriptedWindows] overrides the noise field for Precision
///    Trials (handcrafted thermal / turbulence lanes).
///  - Zen Flight scales the whole field down via [GameConfig.zenWindScale]
///    and never spawns turbulence.
class WindSystem extends Component with HasGameRef<PaperFlightGame> {
  WindSystem({int? seed})
      : _noise = ValueNoise(seed: seed ?? 7),
        _rng = math.Random(seed ?? 7);

  final ValueNoise _noise;
  final math.Random _rng;
  double _time = 0;
  double _nextTurbulenceAt = 2;
  final List<_Pocket> _pockets = [];

  /// Scripted wind lane windows for Precision Trials (null = natural noise).
  List<ScriptedWindWindow>? scriptedWindows;

  List<TurbulencePocket> get turbulencePockets => _pockets
      .map((p) => TurbulencePocket(normX: p.normX, radius: p.radius, ttl: p.ttl))
      .toList(growable: false);

  @override
  void update(double dt) {
    // Only while playing: keeps the seeded RNG draw sequence identical for
    // every daily run (idle time before the run must not consume draws).
    if (gameRef.phase != GamePhase.playing) return;
    _time += dt * GameConfig.windNoiseTimeScale;
    for (final p in _pockets) { p.ttl -= dt; }
    _pockets.removeWhere((p) => p.ttl <= 0);
    if (_time >= _nextTurbulenceAt && _pockets.length < 3) {
      _maybeSpawnTurbulence();
      _nextTurbulenceAt = _time + _rng.nextDouble() * 4.0 + 3.5;
    }
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
      return const LaneWind(lateralForce: 0, liftBonus: 0, type: WindType.calm, intensity: 0);
    }

    try {
      final session = gameRef.ref.read(gameSessionProvider);
      if (session.activePowerUps.contains(PowerUpType.windCaller)) {
        // Wind Caller power-up: disables adverse wind lanes, creates calm updrafts
        return const LaneWind(
          lateralForce: 0,
          liftBonus: 80.0,
          type: WindType.thermal,
          intensity: 0.6,
        );
      }
    } catch (_) {}

    final noiseVal = _noise.fbm(laneIndex * GameConfig.windNoiseLaneScale, _time, octaves: 3);
    WindType type;
    double lateral;
    double lift = 0;
    if (noiseVal > .65) {
      type = WindType.thermal;
      lateral = noiseVal * GameConfig.maxWindForce * .3 * profile.wind;
      lift = GameConfig.thermalLiftForce * (noiseVal - .65) / .35 * profile.thermal;
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

    final zenScale = gameRef.mode == GameMode.zen ? GameConfig.zenWindScale : 1.0;
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
        return const LaneWind(lateralForce: 0, liftBonus: 0, type: WindType.calm, intensity: 0);
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
          liftBonus: GameConfig.thermalLiftForce * profile.thermal * w.intensity,
          type: WindType.thermal,
          intensity: w.intensity,
        );
      case WindType.turbulent:
        // Deterministic jitter from the seeded noise field.
        final jitter = _noise.fbm(w.laneIndex * 3.7, _time, octaves: 2);
        return LaneWind(
          lateralForce: jitter * GameConfig.maxWindForce * profile.wind * w.intensity,
          liftBonus: 0,
          type: WindType.turbulent,
          intensity: w.intensity,
        );
    }
  }

  int laneForNormX(double normX) => (normX * GameConfig.windLaneCount).floor().clamp(0, GameConfig.windLaneCount - 1);
  bool isInTurbulence(double normX) => _pockets.any((p) => (normX - p.normX).abs() < p.radius);
  List<double> get laneIntensities => List.generate(GameConfig.windLaneCount, (i) => windAt(i).intensity);

  /// Adds a scripted turbulence pocket (Precision Trials). [ttl] seconds.
  void addTurbulencePocket(double normX, double radius, double ttl) {
    _pockets.add(_Pocket(normX: normX, radius: radius, ttl: ttl));
  }

  /// Lets plane mechanics tune gravity/control response without duplicating
  /// biome decisions in individual components.
  AirProfile get profile {
    switch (gameRef.biomeManager.currentBiome) {
      case Biome.backyard: return const AirProfile(wind: .55, thermal: .65, gravity: 1, control: 1.08);
      case Biome.city: return const AirProfile(wind: 1.25, thermal: 1.25, gravity: 1, control: .94);
      case Biome.storm: return const AirProfile(wind: 1.65, thermal: .85, gravity: 1.08, control: .76);
      case Biome.mountain: return const AirProfile(wind: 1.15, thermal: 1.7, gravity: .94, control: .9);
      case Biome.night: return const AirProfile(wind: .78, thermal: .85, gravity: 1, control: 1);
      case Biome.atmosphere: return const AirProfile(wind: .72, thermal: .5, gravity: .58, control: 1.04);
    }
  }

  void reset() {
    _time = 0;
    _nextTurbulenceAt = 2 + _rng.nextDouble() * 4;
    _pockets.clear();
  }

  void _maybeSpawnTurbulence() {
    // Zen Flight never spawns turbulence — the sky stays calm.
    if (gameRef.mode == GameMode.zen) return;
    final chance = gameRef.biomeManager.currentBiome == Biome.storm ? .72 : .32;
    if (_rng.nextDouble() > chance) return;
    _pockets.add(_Pocket(normX: _rng.nextDouble() * .8 + .1, radius: _rng.nextDouble() * .1 + .08, ttl: _rng.nextDouble() * 3 + 2));
  }
}

class AirProfile {
  const AirProfile({required this.wind, required this.thermal, required this.gravity, required this.control});
  final double wind;
  final double thermal;
  final double gravity;
  final double control;
}
class _Pocket { _Pocket({required this.normX, required this.radius, required this.ttl}); final double normX; final double radius; double ttl; }
