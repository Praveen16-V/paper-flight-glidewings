import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('seasonal skin availability', () {
    test('Halloween Pumpkin is available inside its October/November window', () {
      final availability = PaperSkin.pumpkin.seasonalAvailability!;
      expect(availability.isAvailableOn(DateTime(2026, 10, 20)), isTrue);
      expect(availability.isAvailableOn(DateTime(2026, 11, 5, 23, 59)), isTrue);
      expect(availability.isAvailableOn(DateTime(2026, 11, 6)), isFalse);
    });

    test('Winter Snowflake correctly crosses the calendar year', () {
      final availability = PaperSkin.snowflake.seasonalAvailability!;
      expect(availability.isAvailableOn(DateTime(2026, 12, 15)), isTrue);
      expect(availability.isAvailableOn(DateTime(2027, 1, 5)), isTrue);
      expect(availability.isAvailableOn(DateTime(2027, 1, 11)), isFalse);
    });

    test('Dragon Scales is the Lunar New Year rotation', () {
      final availability = PaperSkin.dragonScales.seasonalAvailability!;
      expect(availability.rotation, SeasonalRotation.lunarNewYear);
      expect(availability.isAvailableOn(DateTime(2026, 2, 1)), isTrue);
      expect(availability.isAvailableOn(DateTime(2026, 3, 1)), isFalse);
    });

    test('evergreen skins have no limited purchase window', () {
      expect(PaperSkin.graphPaper.seasonalAvailability, isNull);
      expect(
        PaperSkin.graphPaper.isAvailableForPurchaseAt(DateTime(2026, 8, 11)),
        isTrue,
      );
    });
  });
}
