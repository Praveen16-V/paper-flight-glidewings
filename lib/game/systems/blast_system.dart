import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../components/effects/coin_feedback.dart';
import '../components/effects/laser_bolt_component.dart';
import '../components/obstacles/obstacle_component.dart';
import '../events/gameplay_event_bus.dart';
import '../paper_flight_game.dart';

/// Blast Mode: while the power-up is up, the plane automatically fires lasers
/// at hazards ahead of it and destroys them.
///
/// The player does not aim or shoot — the promise is "the sky clears itself
/// for a few seconds" — so this system owns the whole loop: cadence, target
/// selection, the kill, and the reward. It is deliberately *not* a
/// screen-wipe: shots are rate-limited, ranged, and confined to a forward
/// cone, so the player still has to fly into danger to benefit.
class BlastSystem extends Component {
  BlastSystem({required this.game});

  final PaperFlightGame game;

  double _cooldown = 0;

  /// Total hazards destroyed this run — surfaced for telemetry/debugging.
  int _killsThisRun = 0;
  int get killsThisRun => _killsThisRun;

  void reset() {
    _cooldown = 0;
    _killsThisRun = 0;
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;
    if (!game.powerUpState.blastActive) {
      // Re-arm so switching Blast Mode on always fires promptly rather than
      // waiting out a cooldown left over from the last activation.
      _cooldown = 0;
      return;
    }

    _cooldown -= dt;
    if (_cooldown > 0) return;
    _cooldown = GameConfig.blastFireInterval;

    final target = _acquireTarget();
    if (target != null) _fireAt(target);
  }

  /// Picks the nearest destructible hazard inside the forward cone.
  ///
  /// "Nearest" is by vertical distance because this is a vertical scroller —
  /// the most urgent threat is always the one about to reach the plane's row,
  /// not the one closest in raw 2D distance.
  ObstacleComponent? _acquireTarget() {
    final planePos = game.plane.position;
    ObstacleComponent? best;
    double bestDistance = double.infinity;

    for (final obstacle in game.obstacleSpawner.activeObstacles) {
      if (!obstacle.isActive || obstacle.isSmashed) continue;
      if (!obstacle.type.isBlastDestructible) continue;

      final centreY = obstacle.position.y + obstacle.size.y * .5;

      // Only shoot at what is ahead: above the plane in a vertical scroller.
      final ahead = planePos.y - centreY;
      if (ahead <= 0 || ahead > GameConfig.blastRange) continue;

      // Keep the fantasy directional rather than omniscient.
      if ((obstacle.position.x - planePos.x).abs() >
          GameConfig.blastAimHalfWidth) {
        continue;
      }

      if (ahead < bestDistance) {
        bestDistance = ahead;
        best = obstacle;
      }
    }
    return best;
  }

  void _fireAt(ObstacleComponent target) {
    final planePos = game.plane.position;
    final impact = Vector2(
      target.position.x,
      target.position.y + target.size.y * .5,
    );

    game.world.add(
      LaserBoltComponent(
        from: planePos.clone(),
        to: impact.clone(),
        color: PowerUpType.blast.visualColor,
      ),
    );

    // The bolt is instantaneous, so the kill resolves on the same frame the
    // beam is drawn — the visual can never claim a hit that did not happen.
    if (!target.destroyByBlast(impact)) return;

    _killsThisRun++;
    game.scoringSystem.addBonusPoints(GameConfig.blastKillPoints);
    game.gameFeelSystem.onNearMiss();
    game.gameplayEvents.emit(ObstacleDestroyedGameplayEvent(target.type));

    game.world.add(
      FloatingScoreText(
        position: impact.clone(),
        text: '+${GameConfig.blastKillPoints}',
        color: const Color(0xFFFF5252),
        fontSize: 15,
      ),
    );
  }
}
