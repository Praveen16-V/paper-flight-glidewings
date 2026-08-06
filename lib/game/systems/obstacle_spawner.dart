import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/object_pool.dart';
import '../components/obstacles/obstacle_component.dart';
import '../paper_flight_game.dart';

/// Manages obstacle spawn timing, object pools, and recycling across all biomes.
///
/// Features:
///  - Object pools for all 9 rich obstacle types to avoid GC stutter.
///  - Dynamic interval scaling tied to world scroll speed.
///  - Anti-clumping intelligent lane distribution and vertical spacing.
///  - Biome-weighted hazard spawning.
class ObstacleSpawner extends Component {
  ObstacleSpawner({required this.game});

  final PaperFlightGame game;

  // Per-type object pools for all 9 obstacle types.
  late final ObjectPool<PowerLineObstacle> _powerLinePool;
  late final ObjectPool<BuildingObstacle> _buildingPool;
  late final ObjectPool<TreeBranchObstacle> _branchPool;
  late final ObjectPool<BirdObstacle> _birdPool;
  late final ObjectPool<DroneObstacle> _dronePool;
  late final ObjectPool<WindTurbineObstacle> _windTurbinePool;
  late final ObjectPool<HotAirBalloonObstacle> _hotAirBalloonPool;
  late final ObjectPool<StormCloudObstacle> _stormCloudPool;
  late final ObjectPool<KiteObstacle> _kitePool;

  // Active obstacles tracked for lifecycle and near-miss scoring.
  final List<ObstacleComponent> _active = [];
  List<ObstacleComponent> get activeObstacles => _active;

  double _spawnTimer = 0;
  double _lastSpawnX = GameConfig.designWidth * 0.5;

  @override
  Future<void> onLoad() async {
    _powerLinePool = ObjectPool(create: PowerLineObstacle.new, initialSize: 3);
    _buildingPool = ObjectPool(create: BuildingObstacle.new, initialSize: 3);
    _branchPool = ObjectPool(create: TreeBranchObstacle.new, initialSize: 4);
    _birdPool = ObjectPool(create: BirdObstacle.new, initialSize: 4);
    _dronePool = ObjectPool(create: DroneObstacle.new, initialSize: 3);
    _windTurbinePool = ObjectPool(create: WindTurbineObstacle.new, initialSize: 3);
    _hotAirBalloonPool = ObjectPool(create: HotAirBalloonObstacle.new, initialSize: 3);
    _stormCloudPool = ObjectPool(create: StormCloudObstacle.new, initialSize: 3);
    _kitePool = ObjectPool(create: KiteObstacle.new, initialSize: 4);

    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;

    _spawnTimer += dt;

    final interval = _currentSpawnInterval();
    if (_spawnTimer >= interval) {
      _spawnTimer = 0;
      _spawnObstacle();
    }
  }

  void reset() {
    _spawnTimer = 0;
    _lastSpawnX = GameConfig.designWidth * 0.5;
    // Return all active obstacles to their pools immediately.
    for (final obs in List.of(_active)) {
      _recycleObstacle(obs);
    }
    _active.clear();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  double _currentSpawnInterval() {
    // Interval shrinks as speed increases — smooth interpolation.
    final speedFraction = (game.scrollSpeed - GameConfig.baseScrollSpeed) /
        (GameConfig.maxScrollSpeed - GameConfig.baseScrollSpeed);
    final baseInterval = MathUtils.lerp(
      GameConfig.obstacleBaseSpawnInterval,
      GameConfig.obstacleMinSpawnInterval,
      speedFraction.clamp(0.0, 1.0),
    );
    // Backyard deliberately gives newcomers broad, calm clearances; mountain
    // passes compress the rhythm into the requested chokepoint feeling.
    final biomeSpacing = switch (game.biomeManager.currentBiome) {
      Biome.backyard => 1.32,
      Biome.city => .96,
      Biome.storm => .88,
      Biome.mountain => .78,
      Biome.night => 1.02,
      Biome.atmosphere => .90,
    };
    return baseInterval * biomeSpacing;
  }

  void _spawnObstacle() {
    final types = ObstacleType.values;
    final weights = types
        .map((t) => game.biomeManager.obstacleWeight(t))
        .toList();

    // Verify at least one obstacle type has positive weight
    final totalWeight = weights.fold<double>(0, (sum, w) => sum + w);
    final chosen = totalWeight > 0
        ? MathUtils.weightedPick(types, weights)
        : ObstacleType.bird;

    final spawnX = _pickSpawnX(chosen);
    _lastSpawnX = spawnX;

    final obs = _acquireObstacle(chosen);
    obs.activate(
      spawnX: spawnX,
      scrollSpeed: game.scrollSpeed,
      recycleCallback: _recycleObstacle,
    );

    game.world.add(obs);
    _active.add(obs);
  }

  double _pickSpawnX(ObstacleType type) {
    // Full width obstacles anchor to 0
    if (type == ObstacleType.powerLine || type == ObstacleType.building) {
      return 0.0;
    }

    // Branch obstacles pick their own side
    if (type == ObstacleType.treeBranch) {
      return math.Random().nextBool() ? 0.0 : GameConfig.designWidth;
    }

    // Dynamic obstacles: distribute smartly away from last spawn point to avoid clumping
    final minX = GameConfig.horizontalEdgeMargin + 35.0;
    final maxX = GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 35.0;

    double candidateX = MathUtils.randomRange(minX, maxX);
    // If candidate is too close to last spawn, shift across screen
    if ((candidateX - _lastSpawnX).abs() < 70.0) {
      if (_lastSpawnX > GameConfig.designWidth * 0.5) {
        candidateX = MathUtils.randomRange(minX, GameConfig.designWidth * 0.45);
      } else {
        candidateX = MathUtils.randomRange(GameConfig.designWidth * 0.55, maxX);
      }
    }

    return candidateX;
  }

  ObstacleComponent _acquireObstacle(ObstacleType type) {
    switch (type) {
      case ObstacleType.powerLine:
        return _powerLinePool.acquire();
      case ObstacleType.building:
        return _buildingPool.acquire();
      case ObstacleType.treeBranch:
        return _branchPool.acquire();
      case ObstacleType.bird:
        return _birdPool.acquire();
      case ObstacleType.drone:
        return _dronePool.acquire();
      case ObstacleType.windTurbine:
        return _windTurbinePool.acquire();
      case ObstacleType.hotAirBalloon:
        return _hotAirBalloonPool.acquire();
      case ObstacleType.stormCloud:
        return _stormCloudPool.acquire();
      case ObstacleType.kite:
        return _kitePool.acquire();
    }
  }

  void _recycleObstacle(ObstacleComponent obs) {
    _active.remove(obs);
    obs.deactivate();
    if (obs.parent != null) game.world.remove(obs);

    switch (obs.type) {
      case ObstacleType.powerLine:
        _powerLinePool.release(obs as PowerLineObstacle);
      case ObstacleType.building:
        _buildingPool.release(obs as BuildingObstacle);
      case ObstacleType.treeBranch:
        _branchPool.release(obs as TreeBranchObstacle);
      case ObstacleType.bird:
        _birdPool.release(obs as BirdObstacle);
      case ObstacleType.drone:
        _dronePool.release(obs as DroneObstacle);
      case ObstacleType.windTurbine:
        _windTurbinePool.release(obs as WindTurbineObstacle);
      case ObstacleType.hotAirBalloon:
        _hotAirBalloonPool.release(obs as HotAirBalloonObstacle);
      case ObstacleType.stormCloud:
        _stormCloudPool.release(obs as StormCloudObstacle);
      case ObstacleType.kite:
        _kitePool.release(obs as KiteObstacle);
    }
  }
}
