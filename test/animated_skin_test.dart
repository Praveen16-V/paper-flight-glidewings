import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/skins/animated_paper_skin.dart';

void main() {
  group('frame-animated paper skins', () {
    test('premium animated skins advertise an eight-frame overlay', () {
      expect(PaperSkin.flipbook.usesFrameAnimation, isTrue);
      expect(PaperSkin.animatedHologram.usesFrameAnimation, isTrue);
      expect(PaperSkin.lavaLamp.usesFrameAnimation, isTrue);
      expect(PaperSkin.flipbook.animationFrameCount, 8);
      expect(AnimatedPaperSkin.frameCount, 8);
    });

    test('static skins stay on the procedural render path', () {
      expect(PaperSkin.graphPaper.usesFrameAnimation, isFalse);
      expect(PaperSkin.graphPaper.animationFrameCount, 0);
    });

    test('Flipbook Flight is a premium unlock without reindexing old skins', () {
      expect(PaperSkin.flipbook.index, PaperSkin.values.length - 1);
      expect(PaperSkin.flipbook.unlockCostCoins, greaterThan(3200));
      expect(PaperSkin.flipbook.unlockCostGems, greaterThan(8));
    });
  });
}
