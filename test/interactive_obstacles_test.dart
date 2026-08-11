import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/obstacles/obstacle_component.dart';

void main() {
  group('interactive kite tethers', () {
    test('only kite hazards opt into the paper-snap interaction taxonomy', () {
      expect(ObstacleType.kite.isSnapInteractive, isTrue);
      expect(ObstacleType.bird.isSnapInteractive, isFalse);
      expect(ObstacleType.paperDragon.isSnapInteractive, isFalse);
      expect(GameConfig.snapInteractionDuration, greaterThan(0));
      expect(
        GameConfig.kiteTetherSnapRewardCoinCount,
        greaterThan(0),
      );
      expect(
        GameConfig.kiteTetherHintReachAhead,
        greaterThan(GameConfig.kiteTetherSnapReachAhead),
      );
    });

    test('kite snap envelope favours a target ahead of the plane', () {
      final kite = KiteObstacle()
        ..activate(
          spawnX: GameConfig.designWidth * .5,
          scrollSpeed: 240,
          rng: math.Random(7),
        );
      final tether = Vector2(kite.position.x, kite.position.y + 20);
      final alignedPlane = Vector2(tether.x, tether.y + 100);
      final sideMiss = Vector2(
        tether.x + GameConfig.kiteTetherSnapHorizontalReach + 1,
        tether.y + 100,
      );
      final lateMiss = Vector2(
        tether.x,
        tether.y + GameConfig.kiteTetherSnapReachAhead + 1,
      );

      expect(kite.snapInteractionDistanceSquaredTo(alignedPlane), isNotNull);
      expect(kite.snapInteractionDistanceSquaredTo(sideMiss), isNull);
      expect(kite.snapInteractionDistanceSquaredTo(lateMiss), isNull);

      kite.recycleAfterInteraction();
      expect(kite.isActive, isFalse);
    });
  });
}
