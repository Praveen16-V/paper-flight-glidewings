import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('plane + skin synergies', () {
    test('Stealth Jet + Carbon Fiber reduces the already slim hitbox', () {
      final bonus = GameConfig.synergyBonus(
        PlaneType.stealthJet,
        PaperSkin.carbonFiber,
      );

      expect(bonus.isActive, isTrue);
      expect(bonus.label, 'Shadow Weave');
      expect(bonus.hitboxScaleMultiplier, lessThan(1.0));
    });

    test('Butterfly + Cherry Blossom enables a petal trail', () {
      final bonus = GameConfig.synergyBonus(
        PlaneType.butterfly,
        PaperSkin.cherryBlossom,
      );

      expect(bonus.trailEffect, SkinTrailEffect.petals);
      expect(bonus.label, 'Petal Drift');
    });

    test('Glider + Graph Paper gets a thermal drafting bonus', () {
      final bonus = GameConfig.synergyBonus(
        PlaneType.glider,
        PaperSkin.graphPaper,
      );
      expect(bonus.thermalLiftMultiplier, greaterThan(1.0));
    });

    test('unmatched pairs stay neutral', () {
      final bonus = GameConfig.synergyBonus(
        PlaneType.dart,
        PaperSkin.newspaper,
      );
      expect(bonus, same(SkinSynergyBonus.none));
      expect(bonus.isActive, isFalse);
    });
  });
}
