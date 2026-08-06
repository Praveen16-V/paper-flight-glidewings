import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/object_pool.dart';
import '../components/obstacles/obstacle_component.dart';
import '../paper_flight_game.dart';

/// Manages obstacle spawn timing, object pools, and recycling.
///
/// Spawn interval shrinks as scroll speed increases — difficulty scales
/// naturally from speed, not just density (per GDD §3).
///
/// Upper-third of screen is biased toward higher hazard density in later
/// biomes (per GDD §3 tuning note).
class ObstacleSpawner extends Component {
  ObstacleSpawner({required this.game});

  final PaperFlightGame game;

  // Per-type object pools.
  late final ObjectPool<PowerLineObstacle> _powerLinePool;
  late final ObjectPool<BuildingObstacle> _buildingPool;
  late final ObjectPool<TreeBranchObstacle> _branchPool;
  late final ObjectPool<BirdObstacle> _birdPool;
  late final ObjectPool<DroneObstacle> _dronePool;

  // Active obstacles tracked for near-miss scoring.
  final List<ObstacleComponent> _active = [];

  double _spawnTimer = 0;
  double _lastSpawnY = 0; // prevents clumping

  @override
  Future<void> onLoad() async {
    _powerLinePool = ObjectPool(create: PowerLineObstacle.new, initialSize: 4);
    _buildingPool = ObjectPool(create: BuildingObstacle.new, initialSize: 3);
    _branchPool = ObjectPool(create: TreeBranchObstacle.new, initialSize: 4);
    _birdPool = ObjectPool(create: BirdObstacle.new, initialSize: 4);
    _dronePool = ObjectPool(create: DroneObstacle.new, initialSize: 3);
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
    _lastSpawnY = 0;
    // Return all active obstacles to their pools immediately.
    for (final obs in List.of(_active)) {
      _recycleObstacle(obs);
    }
    _active.clear();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  double _currentSpawnInterval() {
    // Interval shrinks as speed increases — linear interpolation.
    final speedFraction = (game.scrollSpeed - GameConfig.baseScrollSpeed) /
        (GameConfig.maxScrollSpeed - GameConfig.baseScrollSpeed);
    return MathUtils.lerp(
      GameConfig.obstacleBaseSpawnInterval,
      GameConfig.obstacleMinSpawnInterval,
      speedFraction.clamp(0.0, 1.0),
    );
  }

  void _spawnObstacle() {
    final biome = game.biomeManager.currentBiome;
    final types = ObstacleType.values;
    final weights = types
        .map((t) => game.biomeManager.obstacleWeight(t))
        .toList();

    final chosen = MathUtils.weightedPick(types, weights);

    // Pick a random X, biasing toward upper-third in later biomes.
    final spawnX = _pickSpawnX(biome);

    final obs = _acquireObstacle(chosen);
    obs.activate(
      spawnX: spawnX,
      scrollSpeed: game.scrollSpeed,
      recycleCallback: _recycleObstacle,
    );

    game.world.add(obs);
    _active.add(obs);
  }

  double _pickSpawnX(Biome biome) {
    // Standard random X across screen.
    return MathUtils.randomRange(
      GameConfig.horizontalEdgeMargin + 40,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 40,
    );
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
    }
  }
}
