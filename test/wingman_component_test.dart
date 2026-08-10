import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/game/components/wingman_component.dart';

void main() {
  group('WingmanComponent', () {
    test('starts at its formation offset and closes a delayed follow gap', () {
      final wingman = WingmanComponent(
        formationOffset: Vector2(-66, 28),
        tint: const Color(0xFF80DEEA),
        seed: 7,
      );
      final firstLeader = Vector2(195, 500);
      wingman.activate(firstLeader);

      expect(wingman.position.x, closeTo(129, 0.001));
      expect(wingman.position.y, closeTo(528, 0.001));
      expect(wingman.isNearLeader(firstLeader), isTrue);

      final movedLeader = Vector2(290, 470);
      final desired = movedLeader + wingman.formationOffset;
      final errorBefore = (wingman.position - desired).length;
      wingman.followLeader(movedLeader, 0.25);
      final errorAfter = (wingman.position - desired).length;

      expect(errorAfter, lessThan(errorBefore));
    });

    test('formation tuning grants combo and coin-value support', () {
      expect(GameConfig.wingmanCount, greaterThan(0));
      expect(GameConfig.wingmanComboBonusNotches, greaterThan(0));
      expect(GameConfig.wingmanCoinScoreMultiplier, greaterThan(1.0));
    });
  });
}
