import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/object_pool.dart';
import '../components/powerups/powerup_component.dart';
import '../paper_flight_game.dart';
import '../replay/run_replay_trace.dart';

/// Spawns power-ups procedurally on a slow timer.
///
/// Pacing is distance-aware: pickups arrive a little faster once the sky gets
/// dangerous, and corrupted bargains only start appearing after the opening
/// biomes. An explicit type-weight map keeps the roll readable and immune to
/// enum reordering; back-to-back duplicates are suppressed so the bank fills
/// with variety.
///
/// Task 8: disabled for Zen Flight (no pressure) and Precision Trials
/// (pure skill courses); the Daily Seeded Flight uses a seeded RNG.
class PowerUpSpawner extends Component {
  PowerUpSpawner({required this.game});

  final PaperFlightGame game;

  /// Seed-aware RNG (daily runs). See ObstacleSpawner.random.
  math.Random random = math.Random();

  /// False for Zen Flight and Precision Trials.
  bool autoSpawn = true;

  final Map<PowerUpType, ObjectPool<PowerUpComponent>> _pools = {};
  final List<PowerUpComponent> _active = [];
  int get activeCount => _active.length;

  List<ObjectPoolDiagnostics> get poolDiagnostics =>
      _pools.values.map((pool) => pool.diagnostics).toList(growable: false);

  double _spawnTimer = 0;
  PowerUpType? _lastSpawnedType;

  /// Base spawn weight per type. Ghost and Coin Rush stay slightly rarer to
  /// keep them exciting; Shield leads as the universal lifeline.
  static const Map<PowerUpType, double> _typeWeights = {
    PowerUpType.shield: 1.4,
    PowerUpType.magnet: 1.3,
    PowerUpType.ghost: 1.0,
    PowerUpType.slowMo: 1.2,
    PowerUpType.coinRush: 1.0,
    PowerUpType.doubleScore: 1.1,
    PowerUpType.shrink: 1.0,
    PowerUpType.blackHole: 0.8,
    PowerUpType.giant: 0.9,
  };

  @override
  Future<void> onLoad() async {
    for (final type in PowerUpType.values) {
      _pools[type] = ObjectPool(
        create: () => PowerUpComponent(type: type),
        initialSize: 2,
        maxRetained: GameConfig.powerUpPoolMaxRetained,
        label: 'powerup.${type.name}',
      );
    }
    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;
    if (!autoSpawn) return;
    _spawnTimer += dt;
    if (_spawnTimer >= _currentSpawnInterval()) {
      _spawnTimer = 0;
      _spawnPowerUp();
    }
  }

  /// Pickups keep a relaxed early cadence, then arrive slightly faster once
  /// the run has found its teeth (Storm Front and beyond) — right when a
  /// Shield or Ghost starts mattering.
  double _currentSpawnInterval() {
    final lateRun = game.distanceMeters >= GameConfig.biomeStormEnd;
    return lateRun
        ? GameConfig.powerUpBaseSpawnInterval * 0.82
        : GameConfig.powerUpBaseSpawnInterval;
  }

  void reset() {
    _spawnTimer = 0;
    _lastSpawnedType = null;
    for (final p in List.of(_active)) {
      _recycle(p);
    }
    _active.clear();
  }

  void _spawnPowerUp() {
    // Corrupted bargains are a risk/reward mechanic for pilots who already
    // understand ordinary pickups — never an onboarding surprise.
    final corruptedEligible =
        game.distanceMeters >= GameConfig.corruptedPowerUpStartMeters;
    final corrupted = corruptedEligible &&
            random.nextDouble() < GameConfig.corruptedPowerUpSpawnChance
        ? (random.nextBool()
            ? CorruptedPowerUpType.cursedMagnet
            : CorruptedPowerUpType.unstableGhost)
        : null;
    final PowerUpType type = corrupted?.baseType ?? _pickType();
    _lastSpawnedType = type;

    final spawnPos = Vector2(
      _pickSpawnX(),
      GameConfig.powerUpSpawnY,
    );

    final pu = _pools[type]!.acquire();
    pu.activate(
      spawnPosition: spawnPos,
      corruptedType: corrupted,
      animationSeed: game.runRandom.nextEntitySeed('powerup.${type.name}'),
      recycleCallback: _recycle,
    );
    game.world.add(pu);
    _active.add(pu);
    game.replayTrace.record(
      ReplayTraceKind.powerUpSpawn,
      primary: type.index,
      secondary: corrupted == null ? 0 : corrupted.index + 1,
      x: pu.position.x,
      y: pu.position.y,
    );
  }

  PowerUpType _pickType() {
    // Suppress an immediate repeat of the previous pickup so drops stay
    // varied; fall back to the plain roll when nothing else is available.
    final previous = _lastSpawnedType;
    if (previous != null) {
      final pool = PowerUpType.values.where((t) => t != previous).toList();
      if (pool.length > 1) {
        return _weightedPick(
          pool,
          pool.map((t) => _typeWeights[t] ?? 1.0).toList(),
        );
      }
    }
    final types = PowerUpType.values;
    return _weightedPick(
      types,
      types.map((t) => _typeWeights[t] ?? 1.0).toList(),
    );
  }

  /// Roughly half of all pickups drop near the plane's own lane so chasing
  /// them stays a steering decision rather than a cross-screen scramble; the
  /// rest keep the classic uniform spread.
  double _pickSpawnX() {
    final minX = GameConfig.horizontalEdgeMargin + 30;
    final maxX = GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 30;
    if (random.nextDouble() < 0.5) {
      final lane = game.plane.position.x + random.nextDouble() * 90.0 - 45.0;
      return lane.clamp(minX, maxX).toDouble();
    }
    return minX + random.nextDouble() * (maxX - minX);
  }

  void _recycle(PowerUpComponent pu) {
    _active.remove(pu);
    pu.deactivate();
    if (pu.parent != null) game.world.remove(pu);
    _pools[pu.type]!.release(pu);
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
}
