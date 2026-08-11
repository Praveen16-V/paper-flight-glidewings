import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('power-up status ring configuration', () {
    test('ring geometry is outside the snap charge ring', () {
      expect(
        GameConfig.powerUpStatusRingRadius,
        greaterThan(GameConfig.snapRingRadius),
      );
      expect(GameConfig.powerUpStatusRingStrokeWidth, greaterThan(0));
    });

    test('every power-up has a color-coded ring tint', () {
      for (final type in PowerUpType.values) {
        expect(type.visualColor.alpha, greaterThan(0));
      }
    });
  });
}
