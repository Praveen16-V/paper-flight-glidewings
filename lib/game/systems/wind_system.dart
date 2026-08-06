import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/noise.dart';
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
class WindSystem extends Component with HasGameRef<PaperFlightGame> {
  WindSystem() : _noise = ValueNoise(seed: 7);
  final ValueNoise _noise;
  double _time = 0;
  double _nextTurbulenceAt = 2;
  final List<_Pocket> _pockets = [];

  List<TurbulencePocket> get turbulencePockets => _pockets
      .map((p) => TurbulencePocket(normX: p.normX, radius: p.radius, ttl: p.ttl))
      .toList(growable: false);

  @override
  void update(double dt) {
    _time += dt * GameConfig.windNoiseTimeScale;
    for (final p in _pockets) { p.ttl -= dt; }
    _pockets.removeWhere((p) => p.ttl <= 0);
    if (_time >= _nextTurbulenceAt && _pockets.length < 3) {
      _maybeSpawnTurbulence();
      _nextTurbulenceAt = _time + MathUtils.randomRange(3.5, 7.5);
    }
  }

  LaneWind windAt(int laneIndex) {
    final noiseVal = _noise.fbm(laneIndex * GameConfig.windNoiseLaneScale, _time, octaves: 3);
    final profile = this.profile;
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
    return LaneWind(lateralForce: lateral, liftBonus: lift, type: type, intensity: (noiseVal.abs() * profile.wind).clamp(0.0, 1.0).toDouble());
  }

  int laneForNormX(double normX) => (normX * GameConfig.windLaneCount).floor().clamp(0, GameConfig.windLaneCount - 1);
  bool isInTurbulence(double normX) => _pockets.any((p) => (normX - p.normX).abs() < p.radius);
  List<double> get laneIntensities => List.generate(GameConfig.windLaneCount, (i) => windAt(i).intensity);

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

  void reset() { _time = 0; _nextTurbulenceAt = 2; _pockets.clear(); }

  void _maybeSpawnTurbulence() {
    final chance = gameRef.biomeManager.currentBiome == Biome.storm ? .72 : .32;
    if (MathUtils.randomRange(0, 1) > chance) return;
    _pockets.add(_Pocket(normX: MathUtils.randomRange(.1, .9), radius: MathUtils.randomRange(.08, .18), ttl: MathUtils.randomRange(2, 5)));
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
