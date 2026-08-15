import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

/// Item 3: collecting a power-up activates it immediately, and effects never
/// stack — re-collecting refreshes the timer instead of compounding.
void main() {
  late ProviderContainer container;

  GameSessionNotifier notifier() =>
      container.read(gameSessionProvider.notifier);
  GameSessionState session() => container.read(gameSessionProvider);

  /// Mirrors what PaperFlightGame.applyPowerUp does to session state.
  void collect(PowerUpType type) {
    notifier().activatePowerUp(type);
    notifier().setPowerUpTimer(type, GameConfig.powerUpActiveDuration(type));
  }

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('collecting activates immediately', () {
    test('a collected power-up is active at once, with a full timer', () {
      for (final type in PowerUpType.values) {
        collect(type);
        expect(
          session().activePowerUps,
          contains(type),
          reason: '${type.displayName} must be active the moment it is taken',
        );
        expect(
          session().powerUpRemaining[type],
          GameConfig.powerUpFullDuration(type),
          reason: '${type.displayName} must start on its full duration',
        );
        notifier().deactivatePowerUp(type);
      }
    });

    test('collecting a Shield turns the shield on immediately', () {
      expect(session().shieldActive, isFalse);
      collect(PowerUpType.shield);
      expect(session().shieldActive, isTrue);
    });
  });

  group('nothing stacks', () {
    test('re-collecting refreshes the timer instead of adding a second copy',
        () {
      collect(PowerUpType.ghost);
      final full = session().powerUpRemaining[PowerUpType.ghost]!;

      // Burn most of the clock, then grab another Ghost.
      notifier().tickPowerUpTimers(full * 0.8);
      expect(session().powerUpRemaining[PowerUpType.ghost],
          lessThan(full));

      collect(PowerUpType.ghost);

      // Back to full — not full + leftover.
      expect(session().powerUpRemaining[PowerUpType.ghost], full);
      // Still exactly one active Ghost.
      expect(
        session().activePowerUps.where((t) => t == PowerUpType.ghost).length,
        1,
      );
    });

    test('a refreshed power-up still ends on one timer', () {
      collect(PowerUpType.ghost);
      final full = session().powerUpRemaining[PowerUpType.ghost]!;
      notifier().tickPowerUpTimers(full * 0.5);
      collect(PowerUpType.ghost);

      final expired = notifier().tickPowerUpTimers(full);

      expect(expired, contains(PowerUpType.ghost));
      expect(session().activePowerUps, isEmpty);
    });

    test('active power-ups are a set — duplicates are impossible', () {
      collect(PowerUpType.magnet);
      collect(PowerUpType.magnet);
      collect(PowerUpType.magnet);
      expect(session().activePowerUps.length, 1);
    });

    test('one Shield pickup is a fixed strength, not an accumulating wall', () {
      expect(GameConfig.shieldChargesPerPickup, 1);
    });
  });

  group('the banking system is gone', () {
    test('session state exposes no charge inventory', () {
      // A fresh session has only live effects and their countdowns; there is
      // no bank to inspect, so there is nothing to hold back and fire later.
      const state = GameSessionState();
      expect(state.activePowerUps, isEmpty);
      expect(state.powerUpRemaining, isEmpty);
      expect(state.activeCorruptedPowerUps, isEmpty);
    });

    test('duration takes no burst/empowered variant', () {
      // One duration per type — the value a pickup grants.
      for (final type in PowerUpType.values) {
        expect(GameConfig.powerUpActiveDuration(type),
            GameConfig.powerUpFullDuration(type));
      }
    });
  });
}
