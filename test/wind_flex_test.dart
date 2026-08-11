import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';

void main() {
  group('crosswind wing-flex tuning', () {
    test('calm air leaves crosswind flex at zero', () {
      expect(GameConfig.wingFlexStrengthForForce(0), 0.0);
    });

    test('flex strength is symmetric for left and right gusts', () {
      const full = GameConfig.wingFlexForceForFullStrength;
      expect(GameConfig.wingFlexStrengthForForce(full), closeTo(1.0, 0.0001));
      expect(GameConfig.wingFlexStrengthForForce(-full), closeTo(1.0, 0.0001));
    });

    test('extreme gusts stay visually bounded', () {
      expect(GameConfig.wingFlexStrengthForForce(99999), 1.0);
    });
  });
}
