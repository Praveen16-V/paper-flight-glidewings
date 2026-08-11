import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/models/save_data.dart';

void main() {
  group('Power-up evolution', () {
    test('Magnet and Shield expose a Lv2 evolution', () {
      expect(PowerUpType.magnet.hasEvolution, isTrue);
      expect(PowerUpType.shield.hasEvolution, isTrue);
      expect(PowerUpType.magnet.evolutionCost(2), greaterThan(0));
      expect(PowerUpType.shield.evolutionCost(2), greaterThan(0));
      expect(PowerUpType.magnet.evolutionDescription(2), contains('gems'));
      expect(PowerUpType.shield.evolutionDescription(2), contains('Reflects'));
    });

    test('other power-ups remain safely non-evolvable for now', () {
      expect(PowerUpType.ghost.hasEvolution, isFalse);
      expect(PowerUpType.ghost.evolutionCost(2), 0);
    });

    test('save data defaults missing power-up levels to Lv1', () {
      final save = SaveData();
      expect(save.getPowerUpLevel(PowerUpType.magnet.index), 1);
      expect(GameConfig.magnetLevel2Radius,
          greaterThan(GameConfig.coinMagnetRadius));
    });
  });
}
