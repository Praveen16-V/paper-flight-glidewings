import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

void main() {
  group('charge-based power-ups', () {
    test('timed effects bank as manual charges while persistent effects do not',
        () {
      expect(PowerUpType.magnet.isChargeBased, isTrue);
      expect(PowerUpType.turboDash.isChargeBased, isTrue);
      expect(PowerUpType.shield.isChargeBased, isFalse);
      expect(PowerUpType.decoyClone.isChargeBased, isFalse);
    });

    test('charge inventory is immutable-by-default session state', () {
      const state = GameSessionState();
      expect(state.powerUpCharges, isEmpty);
      expect(GameConfig.chargePowerUpMaxCharges, 3);
      expect(GameConfig.chargePowerUpBurstDuration, 3.0);
    });
  });
}
