import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/models/run_result.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

/// Item 5: active power-ups are visible while they run, and disappear the
/// moment they end.
///
/// The HUD renders directly from `activePowerUps` + `powerUpRemaining`, so
/// these assertions are exactly what the player does or does not see.
void main() {
  late ProviderContainer container;

  GameSessionNotifier notifier() =>
      container.read(gameSessionProvider.notifier);
  GameSessionState session() => container.read(gameSessionProvider);

  void collect(PowerUpType type) {
    notifier().activatePowerUp(type);
    notifier().setPowerUpTimer(type, GameConfig.powerUpActiveDuration(type));
  }

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('shown while running', () {
    test('nothing is displayed before anything is collected', () {
      expect(session().activePowerUps, isEmpty);
      expect(session().powerUpRemaining, isEmpty);
    });

    test('a collected effect is displayed with a countdown', () {
      collect(PowerUpType.magnet);

      expect(session().activePowerUps, contains(PowerUpType.magnet));
      expect(session().powerUpRemaining[PowerUpType.magnet], isNotNull);
    });

    test('the countdown visibly drains while the effect runs', () {
      collect(PowerUpType.magnet);
      final start = session().powerUpRemaining[PowerUpType.magnet]!;

      notifier().tickPowerUpTimers(1.0);
      final mid = session().powerUpRemaining[PowerUpType.magnet]!;

      expect(mid, lessThan(start));
      // Still on screen — only the bar has moved.
      expect(session().activePowerUps, contains(PowerUpType.magnet));
    });

    test('several effects are all displayed at once', () {
      collect(PowerUpType.magnet);
      collect(PowerUpType.ghost);
      collect(PowerUpType.coinRush);

      expect(session().activePowerUps, hasLength(3));
      for (final type in session().activePowerUps) {
        expect(session().powerUpRemaining[type], isNotNull,
            reason: '${type.displayName} must show a countdown');
      }
    });
  });

  group('hidden the moment it ends', () {
    test('an expired effect leaves the display entirely', () {
      collect(PowerUpType.ghost);
      final full = session().powerUpRemaining[PowerUpType.ghost]!;

      notifier().tickPowerUpTimers(full);

      expect(session().activePowerUps, isNot(contains(PowerUpType.ghost)));
      // The countdown goes with it, so no orphaned ring can be drawn.
      expect(session().powerUpRemaining, isNot(contains(PowerUpType.ghost)));
    });

    test('one effect ending does not hide the others', () {
      collect(PowerUpType.blackHole); // 2.5s
      collect(PowerUpType.coinRush); // 6.0s

      notifier().tickPowerUpTimers(
        GameConfig.powerUpActiveDuration(PowerUpType.blackHole),
      );

      expect(session().activePowerUps, isNot(contains(PowerUpType.blackHole)));
      expect(session().activePowerUps, contains(PowerUpType.coinRush));
      expect(session().powerUpRemaining[PowerUpType.coinRush], isNotNull);
    });

    test('a shield spent on impact disappears immediately', () {
      collect(PowerUpType.shield);
      expect(session().activePowerUps, contains(PowerUpType.shield));

      notifier().consumeShield();

      expect(session().activePowerUps, isNot(contains(PowerUpType.shield)));
      expect(session().powerUpRemaining, isNot(contains(PowerUpType.shield)));
      expect(session().shieldActive, isFalse);
    });

    test('every type reliably disappears when its own timer ends', () {
      for (final type in PowerUpType.values) {
        collect(type);
        notifier().tickPowerUpTimers(GameConfig.powerUpFullDuration(type));
        expect(
          session().activePowerUps,
          isNot(contains(type)),
          reason: '${type.displayName} stayed on screen after expiring',
        );
      }
    });
  });

  group('nothing is left on screen when a run ends', () {
    test('a crash clears every live effect', () {
      collect(PowerUpType.ghost);
      collect(PowerUpType.shield);
      notifier().announcePickup(PowerUpType.ghost);

      notifier().clearAllPowerUps();

      expect(session().activePowerUps, isEmpty);
      expect(session().powerUpRemaining, isEmpty);
      expect(session().activeCorruptedPowerUps, isEmpty);
      expect(session().corruptedPowerUpRemaining, isEmpty);
      expect(session().shieldActive, isFalse);
      expect(session().pickupAnnouncement, isNull);
    });

    test('game over leaves no frozen effects behind', () {
      collect(PowerUpType.magnet);
      notifier().activateCorruptedPowerUp(
        CorruptedPowerUpType.cursedMagnet,
        GameConfig.corruptedPowerUpDuration,
      );

      notifier().triggerGameOver(
        const RunResult(
          score: 100,
          distanceMeters: 50,
          coinsCollected: 3,
          nearMisses: 0,
          isNewHighScore: false,
          finalBiome: Biome.city,
        ),
      );

      // The timer tick stops with the run, so anything still active would
      // otherwise hang on the HUD with a half-drained bar forever.
      expect(session().activePowerUps, isEmpty);
      expect(session().powerUpRemaining, isEmpty);
      expect(session().activeCorruptedPowerUps, isEmpty);
      expect(session().shieldActive, isFalse);
    });

    test('ending a Zen flight clears the display', () {
      collect(PowerUpType.slowMo);
      notifier().endZen();
      expect(session().activePowerUps, isEmpty);
      expect(session().powerUpRemaining, isEmpty);
    });

    test('finishing a trial clears the display', () {
      collect(PowerUpType.shrink);
      notifier().completeTrial(
        const TrialOutcome(
          trialId: 1,
          completed: true,
          timedOut: false,
          stars: 3,
          timeUsedSeconds: 20,
          coinsCollected: 5,
          totalCoins: 5,
          isNewBestStars: true,
        ),
      );
      expect(session().activePowerUps, isEmpty);
      expect(session().powerUpRemaining, isEmpty);
    });

    test('reviving resumes with a clean display', () {
      collect(PowerUpType.slowMo);
      collect(PowerUpType.magnet);

      notifier().useRevive();

      // A Slow-Mo that was live at the crash must not follow the player into
      // the revived run.
      expect(session().activePowerUps, isEmpty);
      expect(session().powerUpRemaining, isEmpty);
      expect(session().shieldActive, isFalse);
    });

    test('a new run starts with an empty display', () {
      collect(PowerUpType.ghost);
      notifier().startRun();
      expect(session().activePowerUps, isEmpty);
      expect(session().powerUpRemaining, isEmpty);
    });
  });

  group('corrupted effects follow the same rule', () {
    test('shown while active, gone when expired', () {
      notifier().activateCorruptedPowerUp(
        CorruptedPowerUpType.unstableGhost,
        GameConfig.corruptedPowerUpDuration,
      );
      expect(session().activeCorruptedPowerUps, hasLength(1));

      notifier().tickPowerUpTimers(GameConfig.corruptedPowerUpDuration);

      expect(session().activeCorruptedPowerUps, isEmpty);
      expect(session().corruptedPowerUpRemaining, isEmpty);
    });
  });
}
