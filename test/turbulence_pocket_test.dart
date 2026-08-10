// Data-level coverage for local, rapidly shifting turbulence cells.

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/systems/wind_system.dart';

void main() {
  group('TurbulencePocket', () {
    const pocket = TurbulencePocket(
      normX: 0.50,
      radius: 0.10,
      ttl: 5,
      duration: 10,
      intensity: 0.80,
      lateralForce: -42,
      shiftFrequency: 2.2,
      sourceObstacle: ObstacleType.kite,
    );

    test('reports an accurate horizontal footprint and lifetime', () {
      expect(pocket.contains(0.50), isTrue);
      expect(pocket.contains(0.59), isTrue);
      expect(pocket.contains(0.61), isFalse);
      expect(pocket.lifeFraction, closeTo(0.5, 0.0001));
    });

    test('natural-cell tuning holds the requested five to ten second window',
        () {
      expect(GameConfig.turbulencePocketMinDuration, greaterThanOrEqualTo(5));
      expect(GameConfig.turbulencePocketMaxDuration, lessThanOrEqualTo(10));
      expect(
        GameConfig.turbulencePocketMaxDuration,
        greaterThanOrEqualTo(GameConfig.turbulencePocketMinDuration),
      );
    });
  });
}
