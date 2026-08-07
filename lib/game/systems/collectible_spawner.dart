import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/object_pool.dart';
import '../components/collectibles/coin_component.dart';
import '../paper_flight_game.dart';

/// Spawns coins in lanes and clusters. Pools and recycles [CoinComponent]s.
///
/// Spawns coins in three patterns:
///   - Single: one coin at a random X.
///   - Line: 3–6 coins in a vertical column (follow one another down).
///   - Arc: 5–8 coins in a curved arc — reward for following a wind lane.
///
/// Task 8: the Precision Trial Director calls [spawnCoinAt]/[spawnCoinLine]/
/// [spawnCoinArc] directly for handcrafted courses (auto-spawning disabled),
/// and the Daily Seeded Flight swaps [random] for a seeded generator.
class CollectibleSpawner extends Component {
  CollectibleSpawner({required this.game});

  final PaperFlightGame game;

  /// Seed-aware RNG (daily runs). See ObstacleSpawner.random.
  math.Random random = math.Random();

  /// When false (Precision Trials) no procedural coin batches spawn — the
  /// Trial Director places every coin from the course definition.
  bool autoSpawn = true;

  late final ObjectPool<CoinComponent> _coinPool;
  final List<CoinComponent> _active = [];

  double _spawnTimer = 0;

  @override
  Future<void> onLoad() async {
    _coinPool = ObjectPool(create: CoinComponent.new, initialSize: 20);
    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;
    if (!autoSpawn) return;
    _spawnTimer += dt;
    if (_spawnTimer >= GameConfig.coinBaseSpawnInterval) {
      _spawnTimer = 0;
      _spawnBatch();
    }
  }

  void reset() {
    _spawnTimer = 0;
    for (final c in List.of(_active)) {
      _recycleCoin(c);
    }
    _active.clear();
  }

  // ── Spawn patterns ────────────────────────────────────────────────────────

  void _spawnBatch() {
    final pattern = _weightedPick(
      [_SpawnPattern.single, _SpawnPattern.line, _SpawnPattern.arc],
      [0.4, 0.4, 0.2],
    );
    switch (pattern) {
      case _SpawnPattern.single:
        _spawnSingle();
      case _SpawnPattern.line:
        _spawnLine();
      case _SpawnPattern.arc:
        _spawnArc();
    }
  }

  void _spawnSingle() {
    spawnCoinAt(Vector2(
      GameConfig.horizontalEdgeMargin +
          20 +
          random.nextDouble() *
              (GameConfig.designWidth -
                  GameConfig.horizontalEdgeMargin * 2 -
                  40),
      GameConfig.coinSpawnY,
    ));
  }

  void _spawnLine() {
    final x = GameConfig.horizontalEdgeMargin +
        20 +
        random.nextDouble() *
            (GameConfig.designWidth -
                GameConfig.horizontalEdgeMargin * 2 -
                40);
    final count = random.nextInt(4) + 4;
    for (int i = 0; i < count; i++) {
      spawnCoinAt(Vector2(x, GameConfig.coinSpawnY - i * 36.0));
    }
  }

  void _spawnArc() {
    final centerX = GameConfig.designWidth * 0.25 +
        random.nextDouble() * GameConfig.designWidth * 0.5;
    final count = random.nextInt(4) + 6;
    final radius = 50 + random.nextDouble() * 40;
    spawnCoinArc(
      centerX: centerX,
      startY: GameConfig.coinSpawnY,
      radius: radius,
      count: count,
    );
  }

  /// Spawns a single coin at an absolute world position.
  void spawnCoinAt(Vector2 pos) {
    final coin = _coinPool.acquire();
    coin.activate(spawnPosition: pos, recycleCallback: _recycleCoin);
    game.world.add(coin);
    _active.add(coin);
  }

  /// Spawns a vertical column of [count] coins spaced [spacing] px apart,
  /// rising upward from [startY] (which is usually [GameConfig.coinSpawnY]).
  void spawnCoinLine({
    required double x,
    required double startY,
    int count = 5,
    double spacing = 30,
  }) {
    for (int i = 0; i < count; i++) {
      spawnCoinAt(Vector2(x, startY - i * spacing));
    }
  }

  /// Spawns a curved arc of [count] coins centered at [centerX] (mirrors the
  /// procedural arc used in endless mode).
  void spawnCoinArc({
    required double centerX,
    required double startY,
    double radius = 70,
    int count = 7,
  }) {
    for (int i = 0; i < count; i++) {
      final angle = (i / (count - 1)) * 3.14159;
      final x = centerX + radius * MathUtils.lerp(-1, 1, i / (count - 1));
      final y = startY -
          radius * 0.5 * (1 - (angle - 1.5708).abs() / 1.5708);
      spawnCoinAt(Vector2(x, y));
    }
  }

  /// Rains a short vertical column of coins down at a random X. Used by the
  /// Coin Rush power-up to flood the screen with collectibles.
  void spawnCoinShower() {
    final x = GameConfig.horizontalEdgeMargin +
        25 +
        random.nextDouble() *
            (GameConfig.designWidth -
                GameConfig.horizontalEdgeMargin * 2 -
                50);
    final count = random.nextInt(4) + 5;
    for (int i = 0; i < count; i++) {
      spawnCoinAt(Vector2(x, GameConfig.coinSpawnY - i * 30.0));
    }
  }

  void _recycleCoin(CoinComponent coin) {
    _active.remove(coin);
    coin.deactivate();
    if (coin.parent != null) game.world.remove(coin);
    _coinPool.release(coin);
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

enum _SpawnPattern { single, line, arc }
