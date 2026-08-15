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

    test('does not create a combo from an incomplete pair', () {
      final combos = powerUpCombosFor({PowerUpType.magnet});
      expect(combos, isEmpty);
    });

    test('every remaining combo is built from power-ups that still exist', () {
      for (final combo in PowerUpCombo.values) {
        for (final ingredient in combo.ingredients) {
          expect(
            PowerUpType.values,
            contains(ingredient),
            reason: '${combo.displayName} needs a power-up that was removed',
          );
        }
      }
    });
  });
}
