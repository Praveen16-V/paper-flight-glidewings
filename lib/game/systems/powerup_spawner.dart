import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/object_pool.dart';
import '../components/powerups/powerup_component.dart';
import '../paper_flight_game.dart';

/// Spawns power-ups procedurally on a slow timer.
/// Second Wind is rare (~8% of spawns) to keep it exciting.
class PowerUpSpawner extends Component {
  PowerUpSpawner({required this.game});

  final PaperFlightGame game;

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
    final type = MathUtils.weightedPick(
      PowerUpType.values,
      [
        1.5, // shield
        1.5, // magnet
        1.2, // turbo
        1.0, // slowmo
        0.4, // second wind (rare)
      ],
    );

    final spawnPos = Vector2(
      MathUtils.randomRange(
        GameConfig.horizontalEdgeMargin + 30,
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 30,
      ),
      GameConfig.powerUpSpawnY,
    );

    final pu = _pools[type]!.acquire();
    pu.activate(spawnPosition: spawnPos, recycleCallback: _recycle);
    game.world.add(pu);
    _active.add(pu);
  }

  void _recycle(PowerUpComponent pu) {
    _active.remove(pu);
    pu.deactivate();
    if (pu.parent != null) game.world.remove(pu);
    _pools[pu.type]!.release(pu);
  }
}
