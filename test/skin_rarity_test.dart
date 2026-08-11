import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('PaperSkin rarity tiers', () {
    test('starter paper stays common', () {
      expect(PaperSkin.plain.rarity, SkinRarity.common);
      expect(PaperSkin.customCraft.rarity, SkinRarity.common);
    });

    test('requested premium examples map to their intended tiers', () {
      expect(PaperSkin.carbonFiber.rarity, SkinRarity.epic);
      expect(PaperSkin.goldLeaf.rarity, SkinRarity.legendary);
      expect(PaperSkin.animatedHologram.rarity, SkinRarity.mythic);
      expect(PaperSkin.flipbook.rarity, SkinRarity.mythic);
    });

    test('every tier exposes a display label and fallback color', () {
      for (final rarity in SkinRarity.values) {
        expect(rarity.label, isNotEmpty);
        expect(rarity.color.alpha, greaterThan(0));
      }
    });
  });
}
