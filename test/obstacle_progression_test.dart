import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('distance-based obstacle progression', () {
    test('covers every obstacle family exactly once', () {
      expect(
        GameConfig.obstacleUnlockMeters.keys,
        unorderedEquals(ObstacleType.values),
      );
      expect(
        GameConfig.obstacleUnlockMeters.length,
        ObstacleType.values.length,
      );
    });

    test('introduces one new family every 500 meters after the opening set', () {
      final milestones = GameConfig.obstacleMilestoneProgression;
      final distances = milestones
          .map(GameConfig.obstacleUnlockDistance)
          .toList(growable: false);

      for (var i = 0; i < distances.length; i++) {
        expect(
          distances[i],
          GameConfig.obstacleUnlockIntervalMeters * (i + 1),
          reason: milestones[i].displayName,
        );
      }
    });

    test('a family is unavailable before its marker and available at it', () {
      for (final type in GameConfig.obstacleMilestoneProgression) {
        final marker = GameConfig.obstacleUnlockDistance(type);
        expect(GameConfig.isObstacleUnlocked(type, marker - .01), isFalse);
        expect(GameConfig.isObstacleUnlocked(type, marker), isTrue);
      }
    });

    test('active threat budget rises gradually and remains bounded', () {
      expect(GameConfig.obstacleActiveCapForDistance(0), 4);
      expect(GameConfig.obstacleActiveCapForDistance(1499), 4);
      expect(GameConfig.obstacleActiveCapForDistance(1500), 5);
      expect(GameConfig.obstacleActiveCapForDistance(3000), 6);
      expect(GameConfig.obstacleActiveCapForDistance(30000), 6);
    });
  });
}
