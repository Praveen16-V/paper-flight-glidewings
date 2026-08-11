import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';

void main() {
  group('dynamic difficulty tuning', () {
    test('confident flight raises the target while a safety save provides relief', () {
      final opening = GameConfig.dynamicDifficultyTarget(
        distanceMeters: 0,
        comboGaugeFraction: 0,
        nearMissMomentum: 0,
        safetyRelief: 0,
      );
      final confident = GameConfig.dynamicDifficultyTarget(
        distanceMeters: 4000,
        comboGaugeFraction: 1,
        nearMissMomentum: 1,
        safetyRelief: 0,
      );
      final relieved = GameConfig.dynamicDifficultyTarget(
        distanceMeters: 4000,
        comboGaugeFraction: 1,
        nearMissMomentum: 1,
        safetyRelief: 1,
      );

      expect(confident, greaterThan(opening));
      expect(relieved, lessThan(confident));
      expect(
        relieved,
        greaterThanOrEqualTo(GameConfig.dynamicDifficultyMinimumIntensity),
      );
    });

    test('pacing becomes denser but stays within safe configured bounds', () {
      final calmInterval =
          GameConfig.dynamicDifficultySpawnIntervalMultiplier(0);
      final intenseInterval =
          GameConfig.dynamicDifficultySpawnIntervalMultiplier(1);
      final calmCombination =
          GameConfig.dynamicDifficultyCombinationChanceMultiplier(0);
      final intenseCombination =
          GameConfig.dynamicDifficultyCombinationChanceMultiplier(1);

      expect(intenseInterval, lessThan(calmInterval));
      expect(intenseInterval, greaterThanOrEqualTo(0.74));
      expect(intenseCombination, greaterThan(calmCombination));
      expect(intenseCombination, lessThanOrEqualTo(1.38));
    });
  });
}
