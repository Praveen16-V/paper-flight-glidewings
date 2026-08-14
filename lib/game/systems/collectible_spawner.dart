import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/object_pool.dart';
import '../components/collectibles/coin_component.dart';
import '../paper_flight_game.dart';
import '../replay/run_replay_trace.dart';

/// Spawns coins in lanes, clusters, and arcs. Pools and recycles collectibles.
class CollectibleSpawner extends Component {
  CollectibleSpawner({required this.game});

  final PaperFlightGame game;

  math.Random random = math.Random();
  bool autoSpawn = true;

  late final ObjectPool<CoinComponent> _coinPool;
  final List<CoinComponent> _activeCoins = [];
  int get activeCoinCount => _activeCoins.length;

  List<ObjectPoolDiagnostics> get poolDiagnostics => [
        _coinPool.diagnostics,
      ];

  double _spawnTimer = 0;

  @override
  Future<void> onLoad() async {
    _coinPool = ObjectPool(
      create: CoinComponent.new,
      initialSize: 20,
      maxRetained: GameConfig.coinPoolMaxRetained,
      label: 'collectible.coin',
    );
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
    for (final c in List.of(_activeCoins)) {
      _recycleCoin(c);
    }
    _activeCoins.clear();
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
    final roll = random.nextDouble();
    final CollectibleVariant variant;
    String letter = 'P';

    if (roll < 0.06) {
      variant = CollectibleVariant.gem3D;
    } else if (roll < 0.18) {
      variant = CollectibleVariant.stack5x;
    } else if (roll < 0.28) {
      variant = CollectibleVariant.letterTile;
      const letters = ['P', 'A', 'P', 'E', 'R', 'F', 'L', 'I', 'G', 'H', 'T'];
      letter = letters[random.nextInt(letters.length)];
    } else {
      variant = CollectibleVariant.standardCoin;
    }

    spawnCoinAt(
      Vector2(
        GameConfig.horizontalEdgeMargin +
            20 +
            random.nextDouble() *
                (GameConfig.designWidth -
                    GameConfig.horizontalEdgeMargin * 2 -
                    40),
        GameConfig.coinSpawnY,
      ),
      variant: variant,
      letter: letter,
    );
  }

  void _spawnLine() {
    final x = GameConfig.horizontalEdgeMargin +
        20 +
        random.nextDouble() *
            (GameConfig.designWidth -
                GameConfig.horizontalEdgeMargin * 2 -
                40);
    final count = random.nextInt(2) + 3;
    final isStack = random.nextDouble() < 0.20;
    for (int i = 0; i < count; i++) {
      spawnCoinAt(
        Vector2(x, GameConfig.coinSpawnY - i * 36.0),
        variant: (isStack && i == 0) ? CollectibleVariant.stack5x : CollectibleVariant.standardCoin,
      );
    }
  }

  void _spawnArc() {
    final centerX = GameConfig.designWidth * 0.25 +
        random.nextDouble() * GameConfig.designWidth * 0.5;
    final count = random.nextInt(2) + 4;
    final radius = 50 + random.nextDouble() * 40;
    spawnCoinArc(
      centerX: centerX,
      startY: GameConfig.coinSpawnY,
      radius: radius,
      count: count,
    );
  }

  /// Spawns a single coin at an absolute world position.
  void spawnCoinAt(
    Vector2 pos, {
    CollectibleVariant variant = CollectibleVariant.standardCoin,
    String letter = 'P',
  }) {
    final coin = _coinPool.acquire();
    coin.activate(
      spawnPosition: pos,
      variant: variant,
      letter: letter,
      animationSeed: game.runRandom.nextEntitySeed('coin.${variant.name}'),
      recycleCallback: _recycleCoin,
    );
    game.world.add(coin);
    _activeCoins.add(coin);
    game.replayTrace.record(
      ReplayTraceKind.collectibleSpawn,
      primary: variant.index,
      secondary: letter.codeUnitAt(0),
      x: coin.position.x,
      y: coin.position.y,
    );
  }

  /// Spawns a vertical column of [count] coins spaced [spacing] px apart.
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

  /// Spawns a curved arc of [count] coins centered at [centerX].
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

  /// Rains a short vertical column of coins down. Most showers fall near the
  /// plane's own lane so the Coin Rush window reads as "steer into the gold"
  /// instead of a random scatter the player cannot reach in time.
  void spawnCoinShower() {
    final minX = GameConfig.horizontalEdgeMargin + 25;
    final maxX =
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 25;
    final double x;
    if (random.nextDouble() < 0.65) {
      x = (game.plane.position.x + random.nextDouble() * 80.0 - 40.0)
          .clamp(minX, maxX)
          .toDouble();
    } else {
      x = minX + random.nextDouble() * (maxX - minX);
    }
    final count = random.nextInt(4) + 5;
    for (int i = 0; i < count; i++) {
      spawnCoinAt(Vector2(x, GameConfig.coinSpawnY - i * 30.0));
    }
  }

  void _recycleCoin(CoinComponent coin) {
    _activeCoins.remove(coin);
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
