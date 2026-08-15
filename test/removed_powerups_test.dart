import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

/// Item 6: Wind Caller, Decoy Clones and Turbo Dash are gone.
///
/// These assertions are deliberately name-based: if someone reintroduces one
/// of the removed power-ups later, the roster check fails and says so.
void main() {
  const removed = {'windCaller', 'decoyClone', 'turboDash'};

  group('the removed power-ups are gone', () {
    test('none of them appear in the roster', () {
      final names = PowerUpType.values.map((t) => t.name).toSet();
      for (final gone in removed) {
        expect(
          names,
          isNot(contains(gone)),
          reason: '$gone was removed and must not come back',
        );
      }
    });

    test('the roster is exactly the eight surviving power-ups', () {
      expect(
        PowerUpType.values.map((t) => t.name).toList(),
        const [
          'shield',
          'magnet',
          'ghost',
          'slowMo',
          'coinRush',
          'doubleScore',
          'shrink',
          'blackHole',
        ],
      );
    });
  });

  group('Time Dash went with its ingredient', () {
    test('the combo no longer exists', () {
      expect(
        PowerUpCombo.values.map((c) => c.name),
        isNot(contains('timeDash')),
      );
    });

    test('every surviving combo is buildable from surviving power-ups', () {
      // A combo whose ingredient was deleted could never trigger, so it would
      // be dead weight rather than a feature.
      for (final combo in PowerUpCombo.values) {
        expect(combo.ingredients, isNotEmpty);
        for (final ingredient in combo.ingredients) {
          expect(
            PowerUpType.values,
            contains(ingredient),
            reason: '${combo.displayName} depends on a removed power-up',
          );
        }
      }
    });

    test('the surviving combos still detect correctly', () {
      expect(
        powerUpCombosFor({PowerUpType.shield, PowerUpType.ghost}),
        contains(PowerUpCombo.phaseShield),
      );
      expect(
        powerUpCombosFor({PowerUpType.magnet, PowerUpType.coinRush}),
        contains(PowerUpCombo.goldVortex),
      );
    });
  });

  group('no dangling configuration', () {
    test('every remaining type still has full metadata', () {
      for (final type in PowerUpType.values) {
        expect(type.displayName.trim(), isNotEmpty);
        expect(type.pickupSummary.trim(), isNotEmpty);
        expect(type.assetName.trim(), isNotEmpty);
        expect(type.visualColor.alpha, greaterThan(0));
        expect(GameConfig.powerUpFullDuration(type), greaterThan(0));
        expect(GameConfig.powerUpActiveDuration(type), greaterThan(0));
      }
    });

    test('corrupted variants still map onto surviving power-ups', () {
      for (final corrupted in CorruptedPowerUpType.values) {
        expect(PowerUpType.values, contains(corrupted.baseType));
      }
    });

    test('no plane has a removed power-up as its signature', () {
      for (final plane in PlaneType.values) {
        expect(PowerUpType.values, contains(plane.signaturePowerUp));
      }
    });
  });
}
