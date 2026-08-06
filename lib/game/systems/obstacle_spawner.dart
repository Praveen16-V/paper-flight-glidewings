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

  // Active obstacles tracked for near-miss scoring / revive clear.
  final List<ObstacleComponent> _active = [];

  double _spawnTimer = 0;
  double _gracePeriod = 1.5; // seconds of calm at run start

  List<ObstacleComponent> get activeObstacles => List.unmodifiable(_active);

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

    // Grace period at start of run so player can settle.
    if (_gracePeriod > 0) {
      _gracePeriod -= dt;
      return;
    }

    _spawnTimer += dt;

    final interval = _currentSpawnInterval();
    if (_spawnTimer >= interval) {
      _spawnTimer = 0;
      _spawnObstacle();
    }
  }

  void reset() {
    _spawnTimer = 0;
    _gracePeriod = 1.5;
    for (final obs in List.of(_active)) {
      _recycleObstacle(obs);
    }
    _active.clear();
  }

  /// Remove obstacles near the plane (used on revive so player isn't re-killed).
  void clearNearPlane(double planeY, {double radius = 200}) {
    final toClear = _active
        .where((o) => (o.position.y - planeY).abs() < radius)
        .toList();
    for (final obs in toClear) {
      _recycleObstacle(obs);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  double _currentSpawnInterval() {
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
    final weights =
        types.map((t) => game.biomeManager.obstacleWeight(t)).toList();

    // If all weights are 0, skip.
    if (weights.every((w) => w <= 0)) return;

    final chosen = MathUtils.weightedPick(types, weights);
    final spawnX = _pickSpawnX(biome, chosen);

    final obs = _acquireObstacle(chosen);
    obs.activate(
      spawnX: spawnX,
      scrollSpeed: game.scrollSpeed,
      recycleCallback: _recycleObstacle,
    );

    game.world.add(obs);
    _active.add(obs);
  }

  double _pickSpawnX(Biome biome, ObstacleType type) {
    // Full-width obstacles centre themselves in onActivate.
    if (type == ObstacleType.powerLine || type == ObstacleType.building) {
      return GameConfig.designWidth / 2;
    }

    // Later biomes bias hazards toward upper-third reaction pressure —
    // implemented as X clustering toward centre lanes where wind is strongest.
    final lateBiome = biome.index >= Biome.storm.index;
    if (lateBiome && MathUtils.randomRange(0, 1) < 0.4) {
      // Bias toward centre 50% of screen.
      return MathUtils.randomRange(
        GameConfig.designWidth * 0.25,
        GameConfig.designWidth * 0.75,
      );
    }

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
    if (obs.parent != null) {
      obs.removeFromParent();
    }

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
