import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/live_powerup_state.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

/// Item 8: Blast Mode — lasers automatically destroy hazards until it ends.
void main() {
  group('Blast Mode exists as a full power-up', () {
    test('it is in the roster with complete metadata', () {
      expect(PowerUpType.values, contains(PowerUpType.blast));
      expect(PowerUpType.blast.displayName, 'Blast Mode');
      expect(PowerUpType.blast.assetName, 'blast');
      expect(PowerUpType.blast.pickupSummary.trim(), isNotEmpty);
      expect(PowerUpType.blast.visualColor.alpha, greaterThan(0));
    });

    test('it is timed, and the lasers stop when it ends', () {
      expect(GameConfig.powerUpFullDuration(PowerUpType.blast),
          GameConfig.blastDuration);
      expect(GameConfig.blastDuration, greaterThan(0));
    });
  });

  group('firing is deliberately limited, not a screen wipe', () {
    test('shots are rate limited', () {
      expect(GameConfig.blastFireInterval, greaterThan(0));
      // Several shots inside one activation, but not a continuous stream.
      final shots = GameConfig.blastDuration / GameConfig.blastFireInterval;
      expect(shots, greaterThan(3));
      expect(shots, lessThan(60));
    });

    test('targeting is ranged rather than screen-wide', () {
      expect(GameConfig.blastRange, greaterThan(0));
      expect(GameConfig.blastRange, lessThan(GameConfig.designHeight));
    });

    test('targeting is a forward cone, not everything on screen', () {
      expect(GameConfig.blastAimHalfWidth, greaterThan(0));
      // Narrower than half the play area, so flanking hazards survive.
      expect(
        GameConfig.blastAimHalfWidth,
        lessThan(GameConfig.designWidth / 2),
      );
    });

    test('bolts are brief', () {
      expect(GameConfig.blastBoltLifetime, greaterThan(0));
      expect(GameConfig.blastBoltLifetime,
          lessThan(GameConfig.blastFireInterval));
    });

    test('kills pay a bounty', () {
      expect(GameConfig.blastKillPoints, greaterThan(0));
    });
  });

  group('what the lasers can destroy', () {
    test('solid hazards can be shot down', () {
      for (final type in const [
        ObstacleType.bird,
        ObstacleType.drone,
        ObstacleType.kite,
        ObstacleType.building,
        ObstacleType.powerLine,
        ObstacleType.trafficPlane,
        ObstacleType.hotAirBalloon,
        ObstacleType.windTurbine,
      ]) {
        expect(type.isBlastDestructible, isTrue,
            reason: '${type.name} should be destructible by lasers');
      }
    });

    test('the boss and the weather forces resist', () {
      for (final type in const [
        ObstacleType.paperDragon,
        ObstacleType.lightningStrike,
        ObstacleType.tornado,
        ObstacleType.meteorShower,
        ObstacleType.stormCloud,
      ]) {
        expect(type.isBlastDestructible, isFalse,
            reason: '${type.name} must not be destructible by lasers');
      }
    });

    test('it matches Giant Mode exactly, so there is one rule to learn', () {
      for (final type in ObstacleType.values) {
        expect(
          type.isBlastDestructible,
          type.isGiantSmashable,
          reason: '${type.name} should behave the same for both destroyers',
        );
      }
    });
  });

  group('session + live state wiring', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('activating Blast Mode surfaces it to the frame cache', () {
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.activatePowerUp(PowerUpType.blast);
      notifier.setPowerUpTimer(
        PowerUpType.blast,
        GameConfig.powerUpActiveDuration(PowerUpType.blast),
      );

      final snapshot = LivePowerUpState();
      snapshot.syncFrom(container.read(gameSessionProvider));
      expect(snapshot.blastActive, isTrue);

      snapshot.reset();
      expect(snapshot.blastActive, isFalse);
    });

    test('the lasers stop the moment the timer runs out', () {
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.activatePowerUp(PowerUpType.blast);
      notifier.setPowerUpTimer(
        PowerUpType.blast,
        GameConfig.powerUpActiveDuration(PowerUpType.blast),
      );

      final expired =
          notifier.tickPowerUpTimers(GameConfig.blastDuration + 0.1);

      expect(expired, contains(PowerUpType.blast));

      final snapshot = LivePowerUpState();
      snapshot.syncFrom(container.read(gameSessionProvider));
      expect(snapshot.blastActive, isFalse,
          reason: 'firing must stop as soon as the power-up ends');
    });
  });

  group('the two destroyer power-ups stay distinct', () {
    test('Giant is contact-based, Blast is ranged', () {
      // Giant requires touching the hazard (it grows the hitbox); Blast
      // reaches out to hazards the plane never touches.
      expect(GameConfig.giantHitboxScale, greaterThan(1.0));
      expect(GameConfig.blastRange, greaterThan(0));
      expect(PowerUpType.giant.visualColor,
          isNot(PowerUpType.blast.visualColor));
    });
  });
}
