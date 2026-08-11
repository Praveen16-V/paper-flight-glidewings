import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/obstacles/obstacle_component.dart';

void main() {
  group('curated obstacle combinations', () {
    test('each encounter has a readable label and exactly two non-boss members', () {
      for (final combination in ObstacleCombination.values) {
        expect(combination.displayName, isNotEmpty);
        expect(combination.members, hasLength(2));
        expect(
          combination.members.any((member) => member.isBoss),
          isFalse,
        );
      }

      expect(
        ObstacleCombination.stormCrossfire.members,
        orderedEquals([ObstacleType.stormCloud, ObstacleType.lightningStrike]),
      );
      expect(
        ObstacleCombination.kiteRelay.members,
        orderedEquals([ObstacleType.windsock, ObstacleType.kite]),
      );
    });

    test('combination tuning reserves an early, staggered safe-side pattern', () {
      expect(GameConfig.obstacleCombinationStartMeters, greaterThan(0));
      expect(
        GameConfig.obstacleCombinationSpawnChance,
        inInclusiveRange(0.0, 1.0),
      );
      expect(
        GameConfig.obstacleCombinationLeadLaneOffset,
        greaterThan(GameConfig.obstacleCombinationFollowLaneOffset),
      );
      expect(GameConfig.obstacleCombinationFollowSpawnYOffset, lessThan(0));
    });

    test('combination metadata survives activation and clears on recycling', () {
      final kite = KiteObstacle()
        ..activate(
          spawnX: 195,
          scrollSpeed: 240,
          combinationId: ObstacleCombination.kiteRelay.name,
          rng: math.Random(7),
        );

      expect(kite.isCombinationMember, isTrue);
      expect(kite.combinationId, ObstacleCombination.kiteRelay.name);

      kite.deactivate();
      expect(kite.isCombinationMember, isFalse);
      expect(kite.combinationId, isNull);
    });
  });
}
