import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

/// Item 1: every power-up is timed, and the timer is what ends it.
void main() {
  late ProviderContainer container;

  GameSessionNotifier notifier() =>
      container.read(gameSessionProvider.notifier);
  GameSessionState session() => container.read(gameSessionProvider);

  void activate(PowerUpType type) {
    notifier().activatePowerUp(type);
    notifier().setPowerUpTimer(type, GameConfig.powerUpActiveDuration(type));
  }

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('every power-up type carries a countdown', () {
    test('activating any type publishes a positive remaining time', () {
      for (final type in PowerUpType.values) {
        activate(type);
        expect(session().activePowerUps, contains(type));
        expect(
          session().powerUpRemaining[type],
          greaterThan(0),
          reason: '${type.displayName} must publish a countdown',
        );
        notifier().deactivatePowerUp(type);
      }
    });

    test('the Shield is timed like everything else', () {
      activate(PowerUpType.shield);

      expect(session().powerUpRemaining[PowerUpType.shield],
          GameConfig.shieldDuration);
    });
  });

  group('tickPowerUpTimers drains and expires', () {
    test('draining part of the clock keeps the effect alive', () {
      activate(PowerUpType.ghost);
      final full = session().powerUpRemaining[PowerUpType.ghost]!;

      final expired = notifier().tickPowerUpTimers(full / 2);

      expect(expired, isEmpty);
      expect(session().activePowerUps, contains(PowerUpType.ghost));
      expect(session().powerUpRemaining[PowerUpType.ghost],
          closeTo(full / 2, 1e-9));
    });

    test('the effect ends exactly when its timer completes', () {
      activate(PowerUpType.ghost);
      final full = session().powerUpRemaining[PowerUpType.ghost]!;

      final expired = notifier().tickPowerUpTimers(full);

      expect(expired, contains(PowerUpType.ghost));
      expect(session().activePowerUps, isNot(contains(PowerUpType.ghost)));
      expect(session().powerUpRemaining, isNot(contains(PowerUpType.ghost)));
    });

    test('an expiring Shield clears shieldActive', () {
      activate(PowerUpType.shield);
      expect(session().shieldActive, isTrue);

      final expired =
          notifier().tickPowerUpTimers(GameConfig.shieldDuration + 0.1);

      expect(expired, contains(PowerUpType.shield));
      expect(session().shieldActive, isFalse);
      expect(session().activePowerUps, isNot(contains(PowerUpType.shield)));
    });

    test('types expire independently on their own clocks', () {
      // Black Hole (2.5s) is shorter than Coin Rush (6.0s).
      activate(PowerUpType.blackHole);
      activate(PowerUpType.coinRush);

      final expired = notifier().tickPowerUpTimers(
        GameConfig.powerUpActiveDuration(PowerUpType.blackHole),
      );

      expect(expired, contains(PowerUpType.blackHole));
      expect(expired, isNot(contains(PowerUpType.coinRush)));
      expect(session().activePowerUps, contains(PowerUpType.coinRush));
    });

    test('corrupted bargains expire on the same tick authority', () {
      notifier().activateCorruptedPowerUp(
        CorruptedPowerUpType.cursedMagnet,
        GameConfig.corruptedPowerUpDuration,
      );
      expect(session().activeCorruptedPowerUps, isNotEmpty);

      notifier()
          .tickPowerUpTimers(GameConfig.corruptedPowerUpDuration + 0.1);

      expect(session().activeCorruptedPowerUps, isEmpty);
      expect(session().corruptedPowerUpRemaining, isEmpty);
    });

    test('a zero/negative tick is a no-op', () {
      activate(PowerUpType.ghost);
      final before = session().powerUpRemaining[PowerUpType.ghost];

      expect(notifier().tickPowerUpTimers(0), isEmpty);

      expect(session().powerUpRemaining[PowerUpType.ghost], before);
    });
  });

  test('a shield spent on impact clears its countdown too', () {
    activate(PowerUpType.shield);

    notifier().consumeShield();

    expect(session().shieldActive, isFalse);
    expect(session().powerUpRemaining, isNot(contains(PowerUpType.shield)));
  });
}
