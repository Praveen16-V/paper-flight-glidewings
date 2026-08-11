import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/obstacles/obstacle_component.dart';

void main() {
  group('obstacle synergies', () {
    test('each synergy exposes a readable, distinct two-hazard relationship', () {
      for (final synergy in ObstacleSynergy.values) {
        expect(synergy.displayName, isNotEmpty);
        expect(synergy.members, hasLength(2));
        expect(synergy.members.first, isNot(synergy.members.last));
      }

      expect(
        ObstacleSynergy.stormCharge.members,
        orderedEquals([ObstacleType.stormCloud, ObstacleType.lightningStrike]),
      );
      expect(
        ObstacleSynergy.windTether.members,
        orderedEquals([ObstacleType.windsock, ObstacleType.kite]),
      );
    });

    test('synergy link tuning remains local and bounded', () {
      expect(GameConfig.obstacleSynergyMaxHorizontalSeparation, greaterThan(0));
      expect(GameConfig.obstacleSynergyMaxVerticalSeparation, greaterThan(0));
      expect(GameConfig.obstacleSynergyMaxVerticalSeparation, lessThan(400));
      expect(GameConfig.obstacleSynergyRotorSpeedMultiplier, greaterThan(1));
      expect(GameConfig.obstacleSynergyTrafficSpeedMultiplier, greaterThan(1));
    });

    test('pooled obstacles clear and accept linked state changes', () {
      final kite = KiteObstacle()
        ..activate(
          spawnX: 195,
          scrollSpeed: 240,
          rng: math.Random(7),
        );

      expect(kite.activeSynergy, isNull);
      kite.setObstacleSynergy(ObstacleSynergy.windTether);
      expect(kite.activeSynergy, ObstacleSynergy.windTether);
      expect(kite.hasActiveSynergy, isTrue);

      kite.deactivate();
      expect(kite.activeSynergy, isNull);
      expect(kite.hasActiveSynergy, isFalse);
    });
  });
}
