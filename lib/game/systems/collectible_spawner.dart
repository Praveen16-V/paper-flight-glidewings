import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/object_pool.dart';
import '../components/collectibles/coin_component.dart';
import '../components/collectibles/tunnel_ring_component.dart';
import '../components/effects/coin_feedback.dart';
import '../paper_flight_game.dart';

/// Spawns coins in lanes, clusters, and optional Tunnel Rings. Pools and recycles collectibles.
class CollectibleSpawner extends Component {
  CollectibleSpawner({required this.game});

  final PaperFlightGame game;

  math.Random random = math.Random();
  bool autoSpawn = true;

  late final ObjectPool<CoinComponent> _coinPool;
  late final ObjectPool<TunnelRingComponent> _ringPool;
  final List<CoinComponent> _activeCoins = [];
  final List<TunnelRingComponent> _activeRings = [];

  List<ObjectPoolDiagnostics> get poolDiagnostics => [
        _coinPool.diagnostics,
        _ringPool.diagnostics,
      ];

  double _spawnTimer = 0;
  double _tunnelRingTimer = 0;
  int _nextRingChainId = 0;
  final Map<int, _TunnelRingChainState> _ringChains = {};

  @override
  Future<void> onLoad() async {
    _coinPool = ObjectPool(
      create: CoinComponent.new,
      initialSize: 20,
      maxRetained: GameConfig.coinPoolMaxRetained,
      label: 'collectible.coin',
    );
    _ringPool = ObjectPool(
      create: TunnelRingComponent.new,
      initialSize: 6,
      maxRetained: GameConfig.tunnelRingPoolMaxRetained,
      label: 'collectible.tunnel_ring',
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

    _tunnelRingTimer += dt;
    if (_tunnelRingTimer >= GameConfig.tunnelRingSpawnInterval) {
      _tunnelRingTimer = 0;
      _spawnTunnelRing();
    }
  }

  void reset() {
    _spawnTimer = 0;
    _tunnelRingTimer = 0;
    _nextRingChainId = 0;
    _ringChains.clear();
    for (final c in List.of(_activeCoins)) {
      _recycleCoin(c);
    }
    _activeCoins.clear();
    for (final r in List.of(_activeRings)) {
      _recycleRing(r);
    }
    _activeRings.clear();
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

  void _spawnTunnelRing() {
    if (random.nextDouble() < GameConfig.tunnelRingChainSpawnChance) {
      _spawnTunnelRingRun();
      return;
    }

    final x = _ringLaneX(
      GameConfig.horizontalEdgeMargin +
          40 +
          random.nextDouble() *
              (GameConfig.designWidth -
                  GameConfig.horizontalEdgeMargin * 2 -
                  80),
    );
    final roll = random.nextDouble();
    final variant = roll < .22
        ? TunnelRingVariant.precision
        : roll < .48
            ? TunnelRingVariant.drifting
            : TunnelRingVariant.standard;
    spawnTunnelRingAt(
      Vector2(x, GameConfig.coinSpawnY - 20),
      variant: variant,
    );
  }

  void _spawnTunnelRingRun() {
    final chainId = _nextRingChainId++;
    final count = GameConfig.tunnelRingChainMinLength +
        random.nextInt(
          GameConfig.tunnelRingChainMaxLength -
              GameConfig.tunnelRingChainMinLength +
              1,
        );
    _ringChains[chainId] = _TunnelRingChainState(length: count);

    final baseX = _ringLaneX(game.plane.position.x);
    for (var index = 0; index < count; index++) {
      final offset = index.isOdd
          ? GameConfig.tunnelRingChainHorizontalStep
          : 0.0;
      final variant = index == count - 1
          ? TunnelRingVariant.precision
          : index.isOdd
              ? TunnelRingVariant.drifting
              : TunnelRingVariant.standard;
      spawnTunnelRingAt(
        Vector2(
          _ringLaneX(baseX + offset),
          GameConfig.coinSpawnY - 20 -
              index * GameConfig.tunnelRingChainVerticalSpacing,
        ),
        variant: variant,
        chainId: chainId,
        chainIndex: index,
        chainLength: count,
      );
    }
  }

  double _ringLaneX(double desiredX) => desiredX
      .clamp(
        GameConfig.horizontalEdgeMargin + 62,
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 62,
      )
      .toDouble();

  /// Spawns an origami paper tunnel ring at [pos]. Linked run members report
  /// their clear/miss state through the same pooled lifecycle as a single ring.
  void spawnTunnelRingAt(
    Vector2 pos, {
    TunnelRingVariant variant = TunnelRingVariant.standard,
    int? chainId,
    int chainIndex = 0,
    int chainLength = 1,
  }) {
    final ring = _ringPool.acquire();
    ring.activate(
      spawnPosition: pos,
      variant: variant,
      chainId: chainId,
      chainIndex: chainIndex,
      chainLength: chainLength,
      randomSeed: game.runRandom.nextEntitySeed('tunnel_ring.${variant.name}'),
      resolutionCallback: chainId == null ? null : _onTunnelRingResolved,
      recycleCallback: _recycleRing,
    );
    game.world.add(ring);
    _activeRings.add(ring);
  }

  void _onTunnelRingResolved(
    TunnelRingComponent ring,
    TunnelRingResult result,
  ) {
    final id = ring.chainId;
    if (id == null) return;
    final chain = _ringChains[id];
    if (chain == null) return;

    chain.resolvedCount++;
    if (result != TunnelRingResult.perfect) chain.broken = true;
    if (chain.resolvedCount < chain.length) return;

    _ringChains.remove(id);
    if (chain.broken) return;

    // Every member was centered perfectly: turn the run into a memorable
    // precision payout without making any single ordinary ring overpowered.
    game.scoringSystem
        .awardComboNotches(GameConfig.tunnelRingChainCompletionComboNotches);
    game.inputManager
        .restoreSnapCharge(GameConfig.tunnelRingChainCompletionSnapRefund);
    spawnCoinLine(
      x: ring.position.x,
      startY: ring.position.y,
      count: GameConfig.tunnelRingChainCompletionCoinCount,
      spacing: GameConfig.tunnelRingChainVerticalSpacing * .18,
    );
    game.world.add(
      ColoredBurst(
        position: ring.position.clone(),
        color: const Color(0xFFB2EBF2),
      ),
    );
    game.world.add(
      FloatingScoreText(
        position: ring.position.clone(),
        text: 'RING RUN! +BOOST',
        color: const Color(0xFFB2EBF2),
        fontSize: 20,
      ),
    );
    game.gameFeelSystem.onCoinCollected(game.scoringSystem.comboCount);
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

  /// Rains a short vertical column of coins down at a random X.
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
    _activeCoins.remove(coin);
    coin.deactivate();
    if (coin.parent != null) game.world.remove(coin);
    _coinPool.release(coin);
  }

  void _recycleRing(TunnelRingComponent ring) {
    _activeRings.remove(ring);
    ring.deactivate();
    if (ring.parent != null) game.world.remove(ring);
    _ringPool.release(ring);
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

class _TunnelRingChainState {
  _TunnelRingChainState({required this.length});

  final int length;
  int resolvedCount = 0;
  bool broken = false;
}

enum _SpawnPattern { single, line, arc }
