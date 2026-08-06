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
class CollectibleSpawner extends Component {
  CollectibleSpawner({required this.game});

  final PaperFlightGame game;

  late final ObjectPool<CoinComponent> _coinPool;
  final List<CoinComponent> _active = [];

  double _spawnTimer = 0;
  double _gracePeriod = 0.8;

  @override
  Future<void> onLoad() async {
    _coinPool = ObjectPool(create: CoinComponent.new, initialSize: 20);
    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;

    if (_gracePeriod > 0) {
      _gracePeriod -= dt;
      return;
    }

    _spawnTimer += dt;
    if (_spawnTimer >= GameConfig.coinBaseSpawnInterval) {
      _spawnTimer = 0;
      _spawnBatch();
    }
  }

  void reset() {
    _spawnTimer = 0;
    _gracePeriod = 0.8;
    for (final c in List.of(_active)) {
      _recycleCoin(c);
    }
    _active.clear();
  }

  // ── Spawn patterns ────────────────────────────────────────────────────────

  void _spawnBatch() {
    final pattern = MathUtils.weightedPick(
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
    _spawnCoinAt(Vector2(
      MathUtils.randomRange(
        GameConfig.horizontalEdgeMargin + 20,
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 20,
      ),
      GameConfig.coinSpawnY,
    ));
  }

  void _spawnLine() {
    final x = MathUtils.randomRange(
      GameConfig.horizontalEdgeMargin + 20,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 20,
    );
    final count = MathUtils.randomInt(4, 7);
    for (int i = 0; i < count; i++) {
      _spawnCoinAt(Vector2(x, GameConfig.coinSpawnY - i * 36.0));
    }
  }

  void _spawnArc() {
    final centerX = MathUtils.randomRange(
      GameConfig.designWidth * 0.25,
      GameConfig.designWidth * 0.75,
    );
    final count = MathUtils.randomInt(6, 9);
    final radius = MathUtils.randomRange(50, 90);
    for (int i = 0; i < count; i++) {
      final t = count <= 1 ? 0.5 : i / (count - 1);
      final x = centerX + radius * MathUtils.lerp(-1, 1, t);
      final y = GameConfig.coinSpawnY - radius * mathSinArc(t);
      _spawnCoinAt(Vector2(x, y));
    }
  }

  /// Simple arc height 0→1→0.
  double mathSinArc(double t) => 1.0 - (2 * t - 1).abs();

  void _spawnCoinAt(Vector2 pos) {
    final coin = _coinPool.acquire();
    coin.activate(spawnPosition: pos, recycleCallback: _recycleCoin);
    game.world.add(coin);
    _active.add(coin);
  }

  void _recycleCoin(CoinComponent coin) {
    _active.remove(coin);
    coin.deactivate();
    if (coin.parent != null) {
      coin.removeFromParent();
    }
    _coinPool.release(coin);
  }
}

enum _SpawnPattern { single, line, arc }
