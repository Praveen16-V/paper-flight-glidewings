import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/game/components/skins/weathered_paper_skin_painter.dart';
import 'package:paper_flight/models/save_data.dart';

void main() {
  group('persistent skin weathering', () {
    test('missing legacy wear entries read as pristine', () {
      final save = SaveData();
      expect(save.skinWearLevelFor(0), 0.0);
      expect(save.skinWearLevelFor(99), 0.0);
    });

    test('wear is bounded and copied with save data', () {
      final save = SaveData(skinWearLevels: [0.14, 1.4]);
      final copy = save.clone();

      expect(copy.skinWearLevelFor(0), closeTo(0.14, 0.0001));
      expect(copy.skinWearLevelFor(1), 1.0);
      copy.skinWearLevels[0] = 0.9;
      expect(save.skinWearLevelFor(0), closeTo(0.14, 0.0001));
    });

    test('wear variants progress from pristine to veteran', () {
      const painter = WeatheredPaperSkinPainter();
      expect(painter.variantLabel(0.0), 'PRISTINE');
      expect(painter.variantLabel(0.5), 'SEASONED');
      expect(painter.variantLabel(1.0), 'VETERAN');
    });
  });
}
