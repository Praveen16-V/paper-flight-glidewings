import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('ocean whale breach', () {
    test('ocean sits between Night and Atmosphere progression thresholds', () {
      expect(GameConfig.biomeOceanEnd, greaterThan(GameConfig.biomeNightEnd));
      expect(Biome.ocean.displayName, 'Moonlit Ocean');
    });

    test('whale breach is a named ocean obstacle type', () {
      expect(ObstacleType.whaleBreach.displayName, 'Whale Breach');
      expect(ObstacleType.whaleBreach.assetName, 'whale_breach');
    });
  });
}
