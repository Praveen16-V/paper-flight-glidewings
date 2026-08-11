import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('Corrupted power-ups', () {
    test('variants map to their base pickup visuals', () {
      expect(
        CorruptedPowerUpType.cursedMagnet.baseType,
        PowerUpType.magnet,
      );
      expect(
        CorruptedPowerUpType.unstableGhost.baseType,
        PowerUpType.ghost,
      );
    });

    test('cursed magnet tuning pulls danger as well as rewards', () {
      expect(
        GameConfig.cursedMagnetObstaclePullSpeed,
        greaterThan(0),
      );
      expect(
        GameConfig.cursedMagnetRadius,
        greaterThan(GameConfig.coinMagnetRadius),
      );
    });

    test('unstable ghost has a bounded teleport cadence', () {
      expect(GameConfig.unstableGhostTeleportInterval, greaterThan(0));
      expect(GameConfig.unstableGhostTeleportDistance, greaterThan(0));
      expect(CorruptedPowerUpType.unstableGhost.displayName, contains('Ghost'));
    });
  });
}
