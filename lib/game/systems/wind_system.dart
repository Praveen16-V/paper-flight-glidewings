import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/noise.dart';
import '../../core/utils/math_utils.dart';

/// Wind state for a single lane at a given moment.
class LaneWind {
  const LaneWind({
    required this.lateralForce,
    required this.liftBonus,
    required this.type,
    required this.intensity, // 0–1 normalised
  });

  /// Lateral push in px/s. Negative = left, positive = right.
  final double lateralForce;

  /// Additional upward lift in px/s (thermals only, otherwise 0).
  final double liftBonus;

  final WindType type;

  /// Normalised intensity [0,1] for visual feedback.
  final double intensity;
}

/// Manages the per-lane wind field and turbulence pockets.
///
/// The world is divided into [GameConfig.windLaneCount] vertical column-lanes.
/// Each frame [windAt] is sampled to get the current lateral push and
/// lift bonus for the lane the plane is in.
class WindSystem extends Component {
  WindSystem() : _noise = ValueNoise(seed: 7);

  final ValueNoise _noise;
  double _time = 0;

  // Turbulence: list of active turbulence pockets (normalised X 0–1, radius, ttl).
  final List<_TurbulencePocket> _turbulencePockets = [];

  @override
  void update(double dt) {
    _time += dt * GameConfig.windNoiseTimeScale;

    // Occasionally spawn turbulence pockets.
    if (_time.floor() % 7 == 0 && _turbulencePockets.length < 3) {
      _maybeSpawnTurbulence();
    }

    // Tick turbulence TTL.
    for (final p in _turbulencePockets) {
      p.ttl -= dt;
    }
    _turbulencePockets.removeWhere((p) => p.ttl <= 0);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the [LaneWind] for the given [laneIndex] at the current time.
  LaneWind windAt(int laneIndex) {
    final noiseVal = _noise.fbm(
      laneIndex * GameConfig.windNoiseLaneScale,
      _time,
      octaves: 3,
    );

    // Map noise [-1,1] → wind type and force.
    WindType type;
    double lateral;
    double lift = 0.0;

    if (noiseVal > 0.65) {
      type = WindType.thermal;
      lateral = noiseVal * GameConfig.maxWindForce * 0.3;
      lift = GameConfig.thermalLiftForce * (noiseVal - 0.65) / 0.35;
    } else if (noiseVal > 0.25) {
      type = WindType.rightPush;
      lateral = noiseVal * GameConfig.maxWindForce;
    } else if (noiseVal < -0.25) {
      type = WindType.leftPush;
      lateral = noiseVal * GameConfig.maxWindForce;
    } else {
      type = WindType.calm;
      lateral = noiseVal * GameConfig.maxWindForce * 0.2;
    }

    return LaneWind(
      lateralForce: lateral,
      liftBonus: lift,
      type: type,
      intensity: noiseVal.abs().clamp(0.0, 1.0),
    );
  }

  /// Returns the lane index [0, windLaneCount-1] for a normalised X [0,1].
  int laneForNormX(double normX) {
    return (normX * GameConfig.windLaneCount)
        .floor()
        .clamp(0, GameConfig.windLaneCount - 1);
  }

  /// Returns true if the given normalised X position is inside a turbulence
  /// pocket. When true, control precision is reduced.
  bool isInTurbulence(double normX) {
    for (final p in _turbulencePockets) {
      if ((normX - p.normX).abs() < p.radius) return true;
    }
    return false;
  }

  /// Normalised wind intensity for all lanes — used by background shader/UI.
  List<double> get laneIntensities => List.generate(
        GameConfig.windLaneCount,
        (i) => windAt(i).intensity,
      );

  void reset() {
    _time = 0;
    _turbulencePockets.clear();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _maybeSpawnTurbulence() {
    if (MathUtils.randomRange(0, 1) > 0.3) return; // 30% chance per tick
    _turbulencePockets.add(_TurbulencePocket(
      normX: MathUtils.randomRange(0.1, 0.9),
      radius: MathUtils.randomRange(0.08, 0.18),
      ttl: MathUtils.randomRange(2.0, 5.0),
    ));
  }
}

class _TurbulencePocket {
  _TurbulencePocket({
    required this.normX,
    required this.radius,
    required this.ttl,
  });

  final double normX;
  final double radius;
  double ttl;
}
