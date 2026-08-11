import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('stacked power-up combos', () {
    test('detects Phase Shield from Shield + Ghost', () {
      final combos = powerUpCombosFor({
        PowerUpType.shield,
        PowerUpType.ghost,
      });
      expect(combos, contains(PowerUpCombo.phaseShield));
    });

    test('detects Gold Vortex and its three-times coin multiplier', () {
      final combos = powerUpCombosFor({
        PowerUpType.magnet,
        PowerUpType.coinRush,
      });
      expect(combos, contains(PowerUpCombo.goldVortex));
      expect(GameConfig.goldVortexCoinValueMultiplier, 3.0);
    });

    test('detects Time Dash from Slow-Mo + Turbo Dash', () {
      final combos = powerUpCombosFor({
        PowerUpType.slowMo,
        PowerUpType.turboDash,
      });
      expect(combos, contains(PowerUpCombo.timeDash));
      expect(
        GameConfig.timeDashWorldSpeedMultiplier,
        lessThan(GameConfig.slowMoPowerUpMultiplier),
      );
    });

    test('does not create a combo from an incomplete pair', () {
      final combos = powerUpCombosFor({PowerUpType.magnet});
      expect(combos, isEmpty);
    });
  });
}
