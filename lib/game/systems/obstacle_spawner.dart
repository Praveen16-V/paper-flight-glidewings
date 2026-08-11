import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/object_pool.dart';
import '../components/obstacles/obstacle_component.dart';
import '../components/obstacles/obstacle_script.dart';
import '../paper_flight_game.dart';

/// Manages obstacle spawn timing, object pools, and recycling across all biomes.
class ObstacleSpawner extends Component {
  ObstacleSpawner({required this.game});

  final PaperFlightGame game;

  math.Random random = math.Random();
  bool spawnEnabled = true;

  // Per-type object pools for every obstacle type.
  late final ObjectPool<PowerLineObstacle> _powerLinePool;
  late final ObjectPool<BuildingObstacle> _buildingPool;
  late final ObjectPool<TreeBranchObstacle> _branchPool;
  late final ObjectPool<BirdObstacle> _birdPool;
  late final ObjectPool<DroneObstacle> _dronePool;
  late final ObjectPool<WindTurbineObstacle> _windTurbinePool;
  late final ObjectPool<HotAirBalloonObstacle> _hotAirBalloonPool;
  late final ObjectPool<StormCloudObstacle> _stormCloudPool;
  late final ObjectPool<KiteObstacle> _kitePool;
  late final ObjectPool<TrafficPlaneObstacle> _trafficPlanePool;
  late final ObjectPool<FireworksObstacle> _fireworksPool;
  late final ObjectPool<WeatherBalloonObstacle> _weatherBalloonPool;
  late final ObjectPool<ClotheslineObstacle> _clotheslinePool;
  late final ObjectPool<WindSockObstacle> _windSockPool;
  late final ObjectPool<LightningStrikeObstacle> _lightningPool;
  late final ObjectPool<MeteorShowerObstacle> _meteorShowerPool;
  late final ObjectPool<TornadoObstacle> _tornadoPool;
  late final ObjectPool<FlockMigrationObstacle> _flockMigrationPool;
  late final ObjectPool<WhaleBreachObstacle> _whaleBreachPool;
  late final ObjectPool<PaperDragonObstacle> _paperDragonPool;

  final List<ObstacleComponent> _active = [];
  List<ObstacleComponent> get activeObstacles => _active;

  double _spawnTimer = 0;
  double _lastSpawnX = GameConfig.designWidth * 0.5;
  double _safeCorridorX = GameConfig.designWidth * 0.5;

  ObstacleType? _pendingChosen;

  static const double _reactionWindowSeconds = 1.15;
  static const double _corridorHalfWidth = 54.0;

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
    _trafficPlanePool = ObjectPool(create: TrafficPlaneObstacle.new, initialSize: 3);
    _fireworksPool = ObjectPool(create: FireworksObstacle.new, initialSize: 3);
    _weatherBalloonPool = ObjectPool(create: WeatherBalloonObstacle.new, initialSize: 3);
    _clotheslinePool = ObjectPool(create: ClotheslineObstacle.new, initialSize: 3);
    _windSockPool = ObjectPool(create: WindSockObstacle.new, initialSize: 3);
    _lightningPool = ObjectPool(create: LightningStrikeObstacle.new, initialSize: 2);
    _meteorShowerPool = ObjectPool(create: MeteorShowerObstacle.new, initialSize: 2);
    _tornadoPool = ObjectPool(create: TornadoObstacle.new, initialSize: 2);
    _flockMigrationPool =
        ObjectPool(create: FlockMigrationObstacle.new, initialSize: 2);
    _whaleBreachPool = ObjectPool(create: WhaleBreachObstacle.new, initialSize: 1);
    _paperDragonPool = ObjectPool(create: PaperDragonObstacle.new, initialSize: 1);

    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;
    if (!spawnEnabled) return;

    _spawnTimer += dt;

    final interval = _currentSpawnInterval();
    if (_spawnTimer >= interval) {
      if (_spawnObstacle()) _spawnTimer = 0;
    }
  }

  void reset() {
    _spawnTimer = 0;
    _lastSpawnX = GameConfig.designWidth * 0.5;
    _safeCorridorX = GameConfig.designWidth * 0.5;
    _pendingChosen = null;
    for (final obs in List.of(_active)) {
      _recycleObstacle(obs);
    }
    _active.clear();
  }

  /// Resolves one target for the plane's current paper-snap pulse. The closest
  /// eligible target wins, preserving deliberate aim when two kites briefly
  /// overlap the envelope. Precision Trials remain authored obstacle courses,
  /// so their scripted kites deliberately do not become optional shortcuts.
  bool resolveSnapInteraction(Vector2 planePosition) {
    if (game.mode == GameMode.trial) return false;

    ObstacleComponent? target;
    var bestDistanceSquared = double.infinity;
    for (final obstacle in _active) {
      if (!obstacle.type.isSnapInteractive) continue;
      final distanceSquared =
          obstacle.snapInteractionDistanceSquaredTo(planePosition);
      if (distanceSquared == null || distanceSquared >= bestDistanceSquared) {
        continue;
      }
      target = obstacle;
      bestDistanceSquared = distanceSquared;
    }
    return target?.resolveSnapInteraction(planePosition) ?? false;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  double _currentSpawnInterval() {
    final speedFraction = (game.scrollSpeed - GameConfig.baseScrollSpeed) /
        (GameConfig.maxScrollSpeed - GameConfig.baseScrollSpeed);
    final baseInterval = MathUtils.lerp(
      GameConfig.obstacleBaseSpawnInterval,
      GameConfig.obstacleMinSpawnInterval,
      speedFraction.clamp(0.0, 1.0),
    );
    final biomeSpacing = switch (game.biomeManager.currentBiome) {
      Biome.backyard => 1.32,
      Biome.city => .96,
      Biome.storm => .88,
      Biome.mountain => .78,
      Biome.night => 1.02,
      Biome.ocean => .96,
      Biome.atmosphere => .90,
    };
    return baseInterval * biomeSpacing;
  }

  bool _spawnObstacle() {
    final types = ObstacleType.values;
    final weights = types
        .map((t) => game.biomeManager.obstacleWeight(t))
        .toList();

    final totalWeight = weights.fold<double>(0, (sum, w) => sum + w);
    final ObstacleType chosen;
    final pending = _pendingChosen;
    if (pending != null) {
      chosen = pending;
    } else {
      chosen = totalWeight > 0
          ? _weightedPick(types, weights)
          : ObstacleType.bird;
    }

    if (!_hasSafeReactionWindow(chosen)) {
      _pendingChosen = chosen;
      return false;
    }
    _pendingChosen = null;
    _planSafeCorridor();
    final spawnX = _pickSpawnX(chosen);
    _lastSpawnX = spawnX;

    final obs = _acquireObstacle(chosen);
    obs.activate(
      spawnX: spawnX,
      scrollSpeed: game.scrollSpeed,
      safeCorridorX: _safeCorridorX,
      recycleCallback: _recycleObstacle,
      rng: random,
    );

    game.world.add(obs);
    _active.add(obs);

    // Local weather is seeded by a real obstacle event rather than a detached
    // global timer. Gate obstacles use their planned corridor as the anchor so
    // a cell appears beside the route instead of arbitrarily at world x = 0.
    // A Paper Dragon already owns the full readability budget of the screen,
    // so it deliberately never gains an additional turbulence pocket.
    if (!chosen.isBoss) {
      final isGate = chosen == ObstacleType.powerLine ||
          chosen == ObstacleType.building ||
          chosen == ObstacleType.clothesline;
      game.windSystem.spawnTurbulenceAlongsideObstacle(
        anchorX: isGate ? _safeCorridorX : spawnX,
        safeCorridorX: _safeCorridorX,
        obstacleType: chosen,
      );
    }
    return true;
  }

  ObstacleComponent spawnScripted(
    ObstacleType type, {
    required double x,
    ObstacleScript? script,
  }) {
    final obs = _acquireObstacle(type);
    obs.activate(
      spawnX: x,
      scrollSpeed: game.scrollSpeed,
      script: script,
      recycleCallback: _recycleObstacle,
      rng: random,
    );
    game.world.add(obs);
    _active.add(obs);
    return obs;
  }

  T _weightedPick<T>(List<T> items, List<double> weights) {
    final total = weights.fold(0.0, (a, b) => a + b);
    double roll = random.nextDouble() * total;
    for (int i = 0; i < items.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return items[i];
    }
    return items.last;
  }

  bool _hasSafeReactionWindow(ObstacleType proposed) {
    // A boss telegraph means "one challenge at a time". Do not place another
    // obstacle into its S-curve, and only start the encounter after the sky is
    // clear so the long warning remains a fair decision point.
    if (_active.any((obstacle) => obstacle.type.isBoss)) return false;
    if (proposed.isBoss) return _active.isEmpty;

    final isGate = proposed == ObstacleType.powerLine ||
        proposed == ObstacleType.building ||
        proposed == ObstacleType.clothesline;
    if (!isGate &&
        !_active.any((o) =>
            o.type == ObstacleType.powerLine ||
            o.type == ObstacleType.building ||
            o.type == ObstacleType.clothesline)) {
      return true;
    }
    final protectedDistance = game.scrollSpeed * _reactionWindowSeconds + 140;
    return !_active.any((o) => (o.position.y + 80).abs() < protectedDistance);
  }

  void _planSafeCorridor() {
    final reachable = GameConfig.joystickMaxSteerSpeed * _reactionWindowSeconds;
    final desired = game.plane.position.x.clamp(
      GameConfig.horizontalEdgeMargin + _corridorHalfWidth,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - _corridorHalfWidth,
    ).toDouble();
    _safeCorridorX = desired.clamp(
      game.plane.position.x - reachable,
      game.plane.position.x + reachable,
    ).clamp(GameConfig.horizontalEdgeMargin + _corridorHalfWidth,
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - _corridorHalfWidth).toDouble();
  }

  double _pickSpawnX(ObstacleType type) {
    if (type == ObstacleType.powerLine ||
        type == ObstacleType.building ||
        type == ObstacleType.clothesline) {
      return 0.0;
    }

    if (type == ObstacleType.treeBranch) {
      return random.nextBool() ? 0.0 : GameConfig.designWidth;
    }

    final minX = GameConfig.horizontalEdgeMargin + 35.0;
    final maxX = GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 35.0;

    double candidateX = minX + random.nextDouble() * (maxX - minX);
    if ((candidateX - _lastSpawnX).abs() < 70.0) {
      if (_lastSpawnX > GameConfig.designWidth * 0.5) {
        candidateX = minX + random.nextDouble() * (GameConfig.designWidth * 0.45 - minX);
      } else {
        candidateX = GameConfig.designWidth * 0.55 + random.nextDouble() * (maxX - GameConfig.designWidth * 0.55);
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
      case ObstacleType.trafficPlane:
        return _trafficPlanePool.acquire();
      case ObstacleType.fireworks:
        return _fireworksPool.acquire();
      case ObstacleType.weatherBalloon:
        return _weatherBalloonPool.acquire();
      case ObstacleType.clothesline:
        return _clotheslinePool.acquire();
      case ObstacleType.windsock:
        return _windSockPool.acquire();
      case ObstacleType.lightningStrike:
        return _lightningPool.acquire();
      case ObstacleType.meteorShower:
        return _meteorShowerPool.acquire();
      case ObstacleType.tornado:
        return _tornadoPool.acquire();
      case ObstacleType.flockMigration:
        return _flockMigrationPool.acquire();
      case ObstacleType.whaleBreach:
        return _whaleBreachPool.acquire();
      case ObstacleType.paperDragon:
        return _paperDragonPool.acquire();
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
      case ObstacleType.trafficPlane:
        _trafficPlanePool.release(obs as TrafficPlaneObstacle);
      case ObstacleType.fireworks:
        _fireworksPool.release(obs as FireworksObstacle);
      case ObstacleType.weatherBalloon:
        _weatherBalloonPool.release(obs as WeatherBalloonObstacle);
      case ObstacleType.clothesline:
        _clotheslinePool.release(obs as ClotheslineObstacle);
      case ObstacleType.windsock:
        _windSockPool.release(obs as WindSockObstacle);
      case ObstacleType.lightningStrike:
        _lightningPool.release(obs as LightningStrikeObstacle);
      case ObstacleType.meteorShower:
        _meteorShowerPool.release(obs as MeteorShowerObstacle);
      case ObstacleType.tornado:
        _tornadoPool.release(obs as TornadoObstacle);
      case ObstacleType.flockMigration:
        _flockMigrationPool.release(obs as FlockMigrationObstacle);
      case ObstacleType.whaleBreach:
        _whaleBreachPool.release(obs as WhaleBreachObstacle);
      case ObstacleType.paperDragon:
        _paperDragonPool.release(obs as PaperDragonObstacle);
    }
  }
}
