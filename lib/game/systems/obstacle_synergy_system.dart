import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../components/obstacles/obstacle_component.dart';
import '../paper_flight_game.dart';

/// Detects local pairs of complementary hazards and enables their temporary
/// linked behaviour. It deliberately evaluates only the small active-obstacle
/// list and changes a member's state only when a link starts or ends.
class ObstacleSynergySystem extends Component {
  ObstacleSynergySystem({required this.game});

  final PaperFlightGame game;

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;

    final active = game.obstacleSpawner.activeObstacles;
    final synergiesEnabled =
        game.mode != GameMode.trial && game.mode != GameMode.zen;
    for (final obstacle in active) {
      if (!obstacle.isActive) continue;
      obstacle.setObstacleSynergy(
        synergiesEnabled ? _synergyFor(obstacle, active) : null,
      );
    }
  }

  ObstacleSynergy? _synergyFor(
    ObstacleComponent source,
    List<ObstacleComponent> active,
  ) {
    for (final synergy in ObstacleSynergy.values) {
      final members = synergy.members;
      if (!members.contains(source.type)) continue;
      final counterpartType =
          members.firstWhere((type) => type != source.type);

      for (final candidate in active) {
        if (identical(candidate, source) ||
            !candidate.isActive ||
            candidate.type != counterpartType) {
          continue;
        }
        final dx = (candidate.position.x - source.position.x).abs();
        final dy = ((candidate.position.y + candidate.size.y * .5) -
                (source.position.y + source.size.y * .5))
            .abs();
        if (dx <= GameConfig.obstacleSynergyMaxHorizontalSeparation &&
            dy <= GameConfig.obstacleSynergyMaxVerticalSeparation) {
          return synergy;
        }
      }
    }
    return null;
  }

  void reset() {
    for (final obstacle in game.obstacleSpawner.activeObstacles) {
      obstacle.setObstacleSynergy(null);
    }
  }
}
