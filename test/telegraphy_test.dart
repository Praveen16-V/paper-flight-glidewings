import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('Telegraphy 2.0 profiles', () {
    test('hazards map to readable collision-intent presentations', () {
      expect(
        ObstacleType.lightningStrike.telegraphStyle,
        ObstacleTelegraphStyle.lane,
      );
      expect(
        ObstacleType.tornado.telegraphStyle,
        ObstacleTelegraphStyle.area,
      );
      expect(
        ObstacleType.flockMigration.telegraphStyle,
        ObstacleTelegraphStyle.formation,
      );
      expect(
        ObstacleType.powerLine.telegraphStyle,
        ObstacleTelegraphStyle.gate,
      );
      expect(
        ObstacleType.paperDragon.telegraphStyle,
        ObstacleTelegraphStyle.boss,
      );
    });

    test('arrival dial and intent projection stay bounded and actionable', () {
      expect(GameConfig.telegraphCountdownRadius, greaterThan(14));
      expect(GameConfig.telegraphProjectionDepth, greaterThan(0));
      expect(GameConfig.telegraphProjectionDepth, lessThan(120));
      expect(GameConfig.telegraphCountdownTickCount, greaterThan(1));
      expect(GameConfig.telegraphTrajectoryChevronCount, greaterThan(1));
      expect(GameConfig.telegraphGatePreviewHeight, greaterThan(0));
    });
  });
}
