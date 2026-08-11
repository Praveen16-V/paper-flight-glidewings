import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/obstacles/obstacle_component.dart';

void main() {
  group('destructible obstacles', () {
    test('only the intended fragile hazards expose integrity budgets', () {
      expect(ObstacleType.drone.destructibleHitPoints, 2);
      expect(ObstacleType.hotAirBalloon.destructibleHitPoints, 1);
      expect(ObstacleType.fireworks.destructibleHitPoints, 1);
      expect(ObstacleType.weatherBalloon.destructibleHitPoints, 1);
      expect(ObstacleType.tornado.isDestructible, isFalse);
      expect(ObstacleType.paperDragon.isDestructible, isFalse);
    });

    test('a fragile target initializes and clears its snap integrity safely', () {
      final balloon = WeatherBalloonObstacle()
        ..activate(
          spawnX: 195,
          scrollSpeed: 240,
          rng: math.Random(7),
        );
      final targetCenter =
          Vector2(balloon.position.x, balloon.position.y + balloon.size.y * .5);
      final planeAhead = Vector2(targetCenter.x, targetCenter.y + 100);

      expect(balloon.isDestructible, isTrue);
      expect(balloon.acceptsSnapInteraction, isTrue);
      expect(balloon.durability, 1);
      expect(balloon.durabilityFraction, 1.0);
      expect(balloon.snapInteractionDistanceSquaredTo(planeAhead), isNotNull);

      balloon.deactivate();
      expect(balloon.durability, 0);
      expect(balloon.acceptsSnapInteraction, isTrue);
    });

    test('destruction rewards retain a bounded tactical payout', () {
      expect(GameConfig.destructibleSnapChargeRefund, greaterThan(0));
      expect(GameConfig.destructibleDestroyComboNotches, greaterThan(0));
      expect(GameConfig.destructibleDestroyCoinCount, greaterThan(0));
      expect(GameConfig.destructibleSnapReachAhead, greaterThan(0));
    });
  });
}
