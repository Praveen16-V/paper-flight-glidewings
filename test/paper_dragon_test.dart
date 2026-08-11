import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/obstacles/obstacle_component.dart';

void main() {
  group('Paper Dragon boss obstacle', () {
    test('has an explicit identity and stays out of projectile taxonomies', () {
      expect(ObstacleType.paperDragon.displayName, 'Paper Dragon');
      expect(ObstacleType.paperDragon.assetName, 'paper_dragon');
      expect(ObstacleType.paperDragon.isBoss, isTrue);
      expect(ObstacleType.paperDragon.isReflectableProjectile, isFalse);
      expect(ObstacleType.paperDragon.isCursedMagnetAttractable, isFalse);
    });

    test('uses a readable, reusable multi-segment encounter configuration', () {
      final dragon = PaperDragonObstacle()
        ..activate(
          spawnX: 60,
          scrollSpeed: 480,
          rng: math.Random(7),
        );

      expect(PaperDragonObstacle.segmentCount, greaterThanOrEqualTo(8));
      expect(
        dragon.activeSegmentCount,
        GameConfig.paperDragonSegmentCount,
      );
      expect(dragon.segmentHitboxCount, GameConfig.paperDragonSegmentCount);
      expect(dragon.retainsHitboxesWhenInactive, isTrue);
      expect(dragon.position.x, GameConfig.designWidth * .5);
      expect(
        dragon.position.y,
        -GameConfig.paperDragonTelegraphLeadDistance,
      );
      expect(dragon.size.y, GameConfig.paperDragonBodyHeight);
      expect(
        dragon.earlyWarningLeadDistance,
        greaterThan(GameConfig.paperDragonBodyHeight),
      );
      expect(
        GameConfig.paperDragonBodyHeight,
        greaterThan(
          GameConfig.paperDragonHeadOffsetY +
              (GameConfig.paperDragonSegmentCount - 1) *
                  GameConfig.paperDragonSegmentSpacing +
              GameConfig.paperDragonSegmentRadius,
        ),
      );
    });
  });
}
