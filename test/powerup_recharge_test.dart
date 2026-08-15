import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

/// Item 10: one boost on a 30s recharge, and a recharge timer on every
/// power-up after it is used.
void main() {
  group('the basic flight has a single boost', () {
    test('only one charge is carried', () {
      expect(GameConfig.snapMaxCharges, 1);
    });

    test('it recharges on a 30 second wall clock', () {
      expect(GameConfig.snapRechargeSeconds, 30.0);
    });
  });

  group('every power-up recharges after use', () {
    test('each type declares a positive recharge', () {
      for (final type in PowerUpType.values) {
        expect(
          GameConfig.powerUpRechargeFor(type),
          greaterThan(0),
          reason: '${type.displayName} must have a recharge',
        );
      }
    });

    test('the strongest effects wait the longest', () {
      // The two destroyers trivialise hazards while up.
      for (final strong in const [PowerUpType.giant, PowerUpType.blast]) {
        expect(
          GameConfig.powerUpRechargeFor(strong),
          greaterThan(GameConfig.powerUpRechargeFor(PowerUpType.magnet)),
          reason: '${strong.displayName} should recharge slower than Magnet',
        );
      }
    });

    test('a recharge outlasts the effect it follows', () {
      // Otherwise a type could be re-collected before its own cooldown ended,
      // making the cooldown meaningless.
      for (final type in PowerUpType.values) {
        expect(
          GameConfig.powerUpRechargeFor(type),
          greaterThan(GameConfig.powerUpFullDuration(type)),
          reason: '${type.displayName} recharges faster than it lasts',
        );
      }
    });
  });

  group('cooldown lifecycle', () {
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

    test('nothing is recharging at the start of a run', () {
      expect(session().powerUpCooldowns, isEmpty);
      for (final type in PowerUpType.values) {
        expect(session().isRecharging(type), isFalse);
      }
    });

    test('an effect that expires starts recharging', () {
      collect(PowerUpType.ghost);
      expect(session().isRecharging(PowerUpType.ghost), isFalse);

      notifier().tickPowerUpTimers(GameConfig.ghostDuration);

      expect(session().isRecharging(PowerUpType.ghost), isTrue);
      expect(
        session().powerUpCooldowns[PowerUpType.ghost],
        GameConfig.powerUpRechargeFor(PowerUpType.ghost),
      );
    });

    test('the cooldown drains and then clears', () {
      collect(PowerUpType.ghost);
      notifier().tickPowerUpTimers(GameConfig.ghostDuration);
      final full = session().powerUpCooldowns[PowerUpType.ghost]!;

      notifier().tickPowerUpTimers(full / 2);
      expect(session().powerUpCooldowns[PowerUpType.ghost],
          closeTo(full / 2, 1e-9));
      expect(session().isRecharging(PowerUpType.ghost), isTrue);

      notifier().tickPowerUpTimers(full);
      expect(session().isRecharging(PowerUpType.ghost), isFalse);
      expect(session().powerUpCooldowns, isEmpty);
    });

    test('a shield spent on impact also starts recharging', () {
      collect(PowerUpType.shield);
      notifier().consumeShield();
      expect(session().isRecharging(PowerUpType.shield), isTrue);
    });

    test('one type recharging does not block a different type', () {
      collect(PowerUpType.ghost);
      notifier().tickPowerUpTimers(GameConfig.ghostDuration);

      expect(session().isRecharging(PowerUpType.ghost), isTrue);
      expect(session().isRecharging(PowerUpType.magnet), isFalse);
    });

    test('cooldowns keep draining once nothing is active', () {
      collect(PowerUpType.ghost);
      notifier().tickPowerUpTimers(GameConfig.ghostDuration);
      expect(session().activePowerUps, isEmpty);

      // The tick must not early-return just because no effect is live, or a
      // cooldown would freeze forever the moment the last effect ended.
      notifier().tickPowerUpTimers(1.0);

      expect(
        session().powerUpCooldowns[PowerUpType.ghost],
        lessThan(GameConfig.powerUpRechargeFor(PowerUpType.ghost)),
      );
    });

    test('ending a run clears every cooldown', () {
      collect(PowerUpType.ghost);
      notifier().tickPowerUpTimers(GameConfig.ghostDuration);
      expect(session().powerUpCooldowns, isNotEmpty);

      notifier().clearAllPowerUps();

      expect(session().powerUpCooldowns, isEmpty);
    });

    test('reviving does not leave the player mid-cooldown', () {
      collect(PowerUpType.shield);
      notifier().tickPowerUpTimers(GameConfig.shieldDuration);
      expect(session().powerUpCooldowns, isNotEmpty);

      notifier().useRevive();

      expect(session().powerUpCooldowns, isEmpty);
    });

    test('a new run starts with a clean slate', () {
      collect(PowerUpType.ghost);
      notifier().tickPowerUpTimers(GameConfig.ghostDuration);
      notifier().startRun();
      expect(session().powerUpCooldowns, isEmpty);
    });
  });
}
