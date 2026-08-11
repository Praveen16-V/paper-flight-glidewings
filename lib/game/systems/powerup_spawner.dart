import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/object_pool.dart';
import '../components/powerups/powerup_component.dart';
import '../paper_flight_game.dart';

/// Spawns power-ups procedurally on a slow timer.
/// Ghost and Coin Rush are slightly rarer to keep them exciting.
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

  double _spawnTimer = 0;

  @override
  Future<void> onLoad() async {
    for (final type in PowerUpType.values) {
      _pools[type] = ObjectPool(
        create: () => PowerUpComponent(type: type),
        initialSize: 2,
      );
    }
    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;
    if (!autoSpawn) return;
    _spawnTimer += dt;
    if (_spawnTimer >= GameConfig.powerUpBaseSpawnInterval) {
      _spawnTimer = 0;
      _spawnPowerUp();
    }
  }

  void reset() {
    _spawnTimer = 0;
    for (final p in List.of(_active)) {
      _recycle(p);
    }
    _active.clear();
  }

  void _spawnPowerUp() {
    final corrupted = random.nextDouble() < GameConfig.corruptedPowerUpSpawnChance
        ? (random.nextBool()
            ? CorruptedPowerUpType.cursedMagnet
            : CorruptedPowerUpType.unstableGhost)
        : null;
    final type = corrupted?.baseType ??
        _weightedPick(
          PowerUpType.values,
          [
            1.4, // shield
            1.3, // magnet
            1.0, // ghost
            1.2, // slowmo
            1.0, // coin rush
            1.1, // double score
            1.0, // shrink
            1.0, // wind caller
            0.9, // decoy clone
            0.8, // black hole
            0.9, // turbo dash
          ],
        );

    final spawnPos = Vector2(
      GameConfig.horizontalEdgeMargin +
          30 +
          random.nextDouble() *
              (GameConfig.designWidth -
                  GameConfig.horizontalEdgeMargin * 2 -
                  60),
      GameConfig.powerUpSpawnY,
    );

    final pu = _pools[type]!.acquire();
    pu.activate(
      spawnPosition: spawnPos,
      corruptedType: corrupted,
      recycleCallback: _recycle,
    );
    game.world.add(pu);
    _active.add(pu);
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
