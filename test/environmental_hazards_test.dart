import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('environmental obstacle hazards', () {
    test('new hazards have readable labels and asset identifiers', () {
      for (final type in [
        ObstacleType.lightningStrike,
        ObstacleType.meteorShower,
        ObstacleType.tornado,
      ]) {
        expect(type.displayName, isNotEmpty);
        expect(type.assetName, isNotEmpty);
      }
    });

    test('lightning and tornado participate in danger taxonomies', () {
      expect(ObstacleType.fireworks.isReflectableProjectile, isTrue);
      expect(ObstacleType.tornado.isCursedMagnetAttractable, isFalse);
      expect(ObstacleType.lightningStrike.isCursedMagnetAttractable, isFalse);
    });
  });
}
