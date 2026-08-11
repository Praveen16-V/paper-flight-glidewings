import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

void main() {
  group('Empowered power-up crafting', () {
    test('three normal charges are configured to craft one empowered burst', () {
      expect(GameConfig.chargePowerUpMaxCharges, 3);
      expect(GameConfig.empoweredPowerUpBurstDuration,
          greaterThan(GameConfig.chargePowerUpBurstDuration));
      expect(GameConfig.empoweredPowerUpMaxCharges, greaterThan(0));
    });

    test('a fresh session has no normal or empowered inventory', () {
      const state = GameSessionState();
      expect(state.powerUpCharges, isEmpty);
      expect(state.empoweredPowerUpCharges, isEmpty);
      expect(state.activeEmpoweredPowerUps, isEmpty);
    });

    test('empowered magnet and slow-mo are stronger than base effects', () {
      expect(GameConfig.empoweredMagnetRadius,
          greaterThan(GameConfig.magnetLevel2Radius));
      expect(GameConfig.empoweredSlowMoMultiplier,
          lessThan(GameConfig.slowMoPowerUpMultiplier));
    });
  });
}
