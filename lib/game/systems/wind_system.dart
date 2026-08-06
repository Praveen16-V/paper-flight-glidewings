import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/noise.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';

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
///
/// Wind is the signature mechanic (GDD §4) — shove sideways; tilt fights/rides it.
class WindSystem extends Component with HasGameRef<PaperFlightGame> {
  WindSystem() : _noise = ValueNoise(seed: 7);

  final ValueNoise _noise;
  double _time = 0;
  double _biomeMult = 1.0;

  // Turbulence: list of active turbulence pockets (normalised X 0–1, radius, ttl).
  final List<_TurbulencePocket> _turbulencePockets = [];

  // Cached lane winds for this frame (avoids re-sampling noise).
  final List<LaneWind> _laneCache = [];
  double _cacheTime = -1;

  @override
  void update(double dt) {
    if (!isMounted) return;
    if (gameRef.phase != GamePhase.playing) return;

    _time += dt * GameConfig.windNoiseTimeScale;
    try {
      _biomeMult = gameRef.biomeManager.windIntensityMultiplier;
    } catch (_) {
      _biomeMult = 1.0;
    }
    _cacheTime = -1; // invalidate cache each frame

    // Occasionally spawn turbulence pockets (more often in storm).
    final turbChance = 0.25 * _biomeMult;
    if (_turbulencePockets.length < 3 &&
        MathUtils.randomRange(0, 1) < turbChance * dt) {
      _spawnTurbulence();
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
    _ensureCache();
    final idx = laneIndex.clamp(0, GameConfig.windLaneCount - 1);
    return _laneCache[idx];
  }

  void _ensureCache() {
    if (_cacheTime == _time && _laneCache.length == GameConfig.windLaneCount) {
      return;
    }
    _laneCache.clear();
    for (int i = 0; i < GameConfig.windLaneCount; i++) {
      _laneCache.add(_computeWind(i));
    }
    _cacheTime = _time;
  }

  LaneWind _computeWind(int laneIndex) {
    final noiseVal = _noise.fbm(
      laneIndex * GameConfig.windNoiseLaneScale,
      _time,
      octaves: 3,
    );

    WindType type;
    double lateral;
    double lift = 0.0;

    // Mountain biome: more thermals.
    Biome biome = Biome.backyard;
    try {
      if (isMounted) biome = gameRef.biomeManager.currentBiome;
    } catch (_) {}
    final thermalThreshold = biome == Biome.mountain ? 0.45 : 0.65;

    if (noiseVal > thermalThreshold) {
      type = WindType.thermal;
      lateral = noiseVal * GameConfig.maxWindForce * 0.3 * _biomeMult;
      lift = GameConfig.thermalLiftForce *
          ((noiseVal - thermalThreshold) / (1.0 - thermalThreshold)).clamp(0.0, 1.0);
    } else if (noiseVal > 0.25) {
      type = WindType.rightPush;
      lateral = noiseVal * GameConfig.maxWindForce * _biomeMult;
    } else if (noiseVal < -0.25) {
      type = WindType.leftPush;
      lateral = noiseVal * GameConfig.maxWindForce * _biomeMult;
    } else if (noiseVal.abs() > 0.15 && _biomeMult > 1.2) {
      // Storm: mild values become turbulent.
      type = WindType.turbulent;
      lateral = noiseVal * GameConfig.maxWindForce * 0.5 * _biomeMult;
    } else {
      type = WindType.calm;
      lateral = noiseVal * GameConfig.maxWindForce * 0.2 * _biomeMult;
    }

    return LaneWind(
      lateralForce: lateral,
      liftBonus: lift,
      type: type,
      intensity: (noiseVal.abs() * _biomeMult).clamp(0.0, 1.0),
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
    // Also turbulent if the lane itself is turbulent type.
    final lane = laneForNormX(normX);
    return windAt(lane).type == WindType.turbulent;
  }

  /// Normalised wind intensity for all lanes — used by HUD / VFX.
  List<double> get laneIntensities {
    _ensureCache();
    return _laneCache.map((w) => w.intensity).toList();
  }

  /// Wind types for all lanes — used by wind lane indicator VFX.
  List<WindType> get laneTypes {
    _ensureCache();
    return _laneCache.map((w) => w.type).toList();
  }

  void reset() {
    _time = 0;
    _biomeMult = 0.4; // backyard calm
    _turbulencePockets.clear();
    _laneCache.clear();
    _cacheTime = -1;
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _spawnTurbulence() {
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
