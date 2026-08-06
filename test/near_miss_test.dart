// Unit tests for the tiered near-miss scoring design (GDD §5).

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('nearMissTierForClearance', () {
    test('death defying at or under 8px', () {
      expect(nearMissTierForClearance(0), NearMissTier.deathDefying);
      expect(nearMissTierForClearance(GameConfig.nearMissDeathDefyingDistance),
          NearMissTier.deathDefying);
    });

    test('hair thin between 8px and 18px', () {
      expect(nearMissTierForClearance(8.1), NearMissTier.hairThin);
      expect(nearMissTierForClearance(GameConfig.nearMissHairThinDistance),
          NearMissTier.hairThin);
    });

    test('close shave between 18px and 32px', () {
      expect(nearMissTierForClearance(18.1), NearMissTier.closeShave);
      expect(nearMissTierForClearance(GameConfig.nearMissCloseShaveDistance),
          NearMissTier.closeShave);
    });

    test('no tier beyond 32px', () {
      expect(nearMissTierForClearance(32.1), isNull);
      expect(nearMissTierForClearance(500), isNull);
    });
  });

  group('NearMissTier info', () {
    test('points scale with risk', () {
      expect(NearMissTier.closeShave.points, 25);
      expect(NearMissTier.hairThin.points, 50);
      expect(NearMissTier.deathDefying.points, 100);
    });

    test('sting is pitch-shifted up for hair-thin and down for death defying',
        () {
      expect(NearMissTier.closeShave.stingPlaybackRate, 1.0);
      expect(NearMissTier.hairThin.stingPlaybackRate, greaterThan(1.0));
      expect(NearMissTier.deathDefying.stingPlaybackRate, lessThan(1.0));
    });
  });
}
