import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/skins/reactive_paper_skin_painter.dart';

void main() {
  group('ReactivePaperSkinPainter', () {
    test('Gold Leaf bursts only after a coin event', () {
      final painter = ReactivePaperSkinPainter(PaperSkin.goldLeaf);
      expect(painter.goldCoinSparkleIntensity, 0.0);

      painter.onGameEvent(SkinGameEvent.coinCollected);
      expect(painter.goldCoinSparkleIntensity, 1.0);
      painter.update(GameConfig.goldLeafCoinSparkleDuration);
      expect(painter.goldCoinSparkleIntensity, 0.0);
    });

    test('Holographic Foil shifts hue after a near miss', () {
      final painter = ReactivePaperSkinPainter(PaperSkin.holographicFoil);
      painter.onGameEvent(SkinGameEvent.nearMiss);

      expect(painter.holographicNearMissIntensity, 1.0);
      expect(painter.holographicHueShiftDegrees, greaterThan(0));
      painter.update(GameConfig.holographicNearMissShiftDuration / 2);
      expect(painter.holographicNearMissIntensity, closeTo(0.5, 0.001));
    });

    test('Dragon Scales pulse only when a shield hit is absorbed', () {
      final painter = ReactivePaperSkinPainter(PaperSkin.dragonScales);
      painter.onGameEvent(SkinGameEvent.shieldHit);
      expect(painter.dragonShieldPulseIntensity, 1.0);

      painter.setSkin(PaperSkin.plain);
      expect(painter.dragonShieldPulseIntensity, 0.0);
    });

    test('unmatched skin-event pairs remain quiet', () {
      final painter = ReactivePaperSkinPainter(PaperSkin.graphPaper);
      painter.onGameEvent(SkinGameEvent.coinCollected);
      painter.onGameEvent(SkinGameEvent.nearMiss);
      painter.onGameEvent(SkinGameEvent.shieldHit);

      expect(painter.goldCoinSparkleIntensity, 0.0);
      expect(painter.holographicNearMissIntensity, 0.0);
      expect(painter.dragonShieldPulseIntensity, 0.0);
    });
  });
}
