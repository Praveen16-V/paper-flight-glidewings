import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

/// Item 4: collecting a power-up tells the player what they just got.
void main() {
  late ProviderContainer container;

  GameSessionNotifier notifier() =>
      container.read(gameSessionProvider.notifier);
  GameSessionState session() => container.read(gameSessionProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('every power-up can describe itself', () {
    test('each type has a non-empty name and effect summary', () {
      for (final type in PowerUpType.values) {
        expect(type.displayName.trim(), isNotEmpty);
        expect(
          type.pickupSummary.trim(),
          isNotEmpty,
          reason: '${type.displayName} needs a summary for its banner',
        );
        // Short enough to read at a glance mid-run.
        expect(
          type.pickupSummary.length,
          lessThanOrEqualTo(30),
          reason: '${type.displayName} summary is too long to read in flight',
        );
      }
    });

    test('corrupted pickups state their downside', () {
      for (final type in CorruptedPowerUpType.values) {
        expect(type.warning.trim(), isNotEmpty);
      }
    });
  });

  group('announcing a pickup', () {
    test('a fresh session has nothing to announce', () {
      expect(session().pickupAnnouncement, isNull);
    });

    test('collecting publishes the name and effect', () {
      notifier().announcePickup(PowerUpType.magnet);

      final a = session().pickupAnnouncement;
      expect(a, isNotNull);
      expect(a!.type, PowerUpType.magnet);
      expect(a.title, 'MAGNET');
      expect(a.subtitle, PowerUpType.magnet.pickupSummary);
      expect(a.isCorrupted, isFalse);
    });

    test('a corrupted pickup warns instead of celebrating', () {
      notifier().announcePickup(
        PowerUpType.magnet,
        corrupted: CorruptedPowerUpType.cursedMagnet,
      );

      final a = session().pickupAnnouncement;
      expect(a!.isCorrupted, isTrue);
      expect(a.title, 'CURSED MAGNET');
      expect(a.subtitle, CorruptedPowerUpType.cursedMagnet.warning);
    });

    test('every type produces a usable announcement', () {
      for (final type in PowerUpType.values) {
        notifier().announcePickup(type);
        final a = session().pickupAnnouncement!;
        expect(a.title, type.displayName.toUpperCase());
        expect(a.subtitle, isNotEmpty);
      }
    });
  });

  group('repeat pickups re-announce', () {
    test('collecting the same type twice yields a new id', () {
      notifier().announcePickup(PowerUpType.ghost);
      final first = session().pickupAnnouncement!.id;

      notifier().announcePickup(PowerUpType.ghost);
      final second = session().pickupAnnouncement!.id;

      // The id is what lets the HUD replay the banner animation rather than
      // treating an identical repeat pickup as "no change".
      expect(second, isNot(first));
    });
  });

  group('dismissing the banner', () {
    test('clearing removes the announcement', () {
      notifier().announcePickup(PowerUpType.shield);
      final id = session().pickupAnnouncement!.id;

      notifier().clearPickupAnnouncement(id);

      expect(session().pickupAnnouncement, isNull);
    });

    test('a stale dismissal cannot hide a newer pickup', () {
      notifier().announcePickup(PowerUpType.shield);
      final staleId = session().pickupAnnouncement!.id;

      // A second pickup lands before the first banner finished its timer.
      notifier().announcePickup(PowerUpType.ghost);

      notifier().clearPickupAnnouncement(staleId);

      final current = session().pickupAnnouncement;
      expect(current, isNotNull);
      expect(current!.type, PowerUpType.ghost);
    });

    test('clearing an empty announcement is safe', () {
      expect(() => notifier().clearPickupAnnouncement(1), returnsNormally);
      expect(session().pickupAnnouncement, isNull);
    });

    test('a new run starts with no leftover banner', () {
      notifier().announcePickup(PowerUpType.coinRush);
      notifier().startRun();
      expect(session().pickupAnnouncement, isNull);
    });
  });

  test('the banner is on screen long enough to read, briefly', () {
    expect(GameConfig.pickupAnnouncementSeconds, greaterThan(1.0));
    expect(GameConfig.pickupAnnouncementSeconds, lessThan(3.0));
  });
}
