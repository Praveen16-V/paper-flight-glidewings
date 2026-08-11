import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/events/gameplay_event_bus.dart';

void main() {
  group('GameplayEventBus', () {
    test('routes events by their concrete typed contract', () {
      final bus = GameplayEventBus();
      NearMissTier? receivedNearMiss;
      DefensiveSaveSource? receivedSave;

      bus.on<NearMissGameplayEvent>((event) {
        receivedNearMiss = event.tier;
      });
      bus.on<DefensiveSaveGameplayEvent>((event) {
        receivedSave = event.source;
      });

      bus.emit(const NearMissGameplayEvent(NearMissTier.hairThin));
      expect(receivedNearMiss, NearMissTier.hairThin);
      expect(receivedSave, isNull);

      bus.emit(const DefensiveSaveGameplayEvent(
        source: DefensiveSaveSource.shieldCharge,
        severity: .85,
      ));
      expect(receivedSave, DefensiveSaveSource.shieldCharge);
      expect(bus.listenerCount<NearMissGameplayEvent>(), 1);
      expect(bus.listenerCount<DefensiveSaveGameplayEvent>(), 1);
    });

    test('subscriptions are safe to cancel during dispatch and after disposal', () {
      final bus = GameplayEventBus();
      var calls = 0;
      late GameplayEventSubscription subscription;
      subscription = bus.on<NearMissGameplayEvent>((event) {
        calls++;
        subscription.cancel();
      });

      bus.emit(const NearMissGameplayEvent(NearMissTier.closeShave));
      bus.emit(const NearMissGameplayEvent(NearMissTier.deathDefying));
      expect(calls, 1);

      bus.dispose();
      subscription.cancel();
      bus.emit(const NearMissGameplayEvent(NearMissTier.closeShave));
      expect(calls, 1);
    });
  });
}
