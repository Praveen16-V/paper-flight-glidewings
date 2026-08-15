import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/live_powerup_state.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

/// Item 7: Giant Mode — the plane grows, and hazards it hits are blasted away.
void main() {
  group('Giant Mode exists as a full power-up', () {
    test('it is in the roster with complete metadata', () {
      expect(PowerUpType.values, contains(PowerUpType.giant));
      expect(PowerUpType.giant.displayName, 'Giant Mode');
      expect(PowerUpType.giant.assetName, 'giant');
      expect(PowerUpType.giant.pickupSummary.trim(), isNotEmpty);
      expect(PowerUpType.giant.visualColor.alpha, greaterThan(0));
    });

    test('it is timed like every other power-up', () {
      expect(GameConfig.powerUpFullDuration(PowerUpType.giant),
          GameConfig.giantDuration);
      expect(GameConfig.powerUpActiveDuration(PowerUpType.giant),
          greaterThan(0));
    });
  });

  group('the plane actually grows', () {
    test('both the art and the hitbox scale up', () {
      expect(GameConfig.giantVisualScale, greaterThan(1.0));
      expect(GameConfig.giantHitboxScale, greaterThan(1.0));
    });

    test('the hitbox grows a little less than the art', () {
      // Contact should still look like contact rather than triggering from
      // empty space around the sprite.
      expect(
        GameConfig.giantHitboxScale,
        lessThan(GameConfig.giantVisualScale),
      );
    });

    test('it is the opposite of Shrink', () {
      expect(
        GameConfig.giantHitboxScale,
        greaterThan(GameConfig.shrinkHitboxScale),
      );
    });
  });

  group('what can and cannot be smashed', () {
    test('ordinary hazards are smashable', () {
      const smashable = [
        ObstacleType.bird,
        ObstacleType.drone,
        ObstacleType.kite,
        ObstacleType.building,
        ObstacleType.powerLine,
        ObstacleType.treeBranch,
        ObstacleType.trafficPlane,
        ObstacleType.hotAirBalloon,
        ObstacleType.windTurbine,
        ObstacleType.fireworks,
        ObstacleType.weatherBalloon,
        ObstacleType.clothesline,
        ObstacleType.windsock,
        ObstacleType.flockMigration,
        ObstacleType.whaleBreach,
      ];
      for (final type in smashable) {
        expect(type.isGiantSmashable, isTrue,
            reason: '${type.name} should be smashable by a giant plane');
      }
    });

    test('the boss resists — Giant Mode is not blanket immunity', () {
      expect(ObstacleType.paperDragon.isGiantSmashable, isFalse);
    });

    test('weather forces cannot be smashed, having nothing solid to hit', () {
      for (final type in const [
        ObstacleType.lightningStrike,
        ObstacleType.tornado,
        ObstacleType.meteorShower,
        ObstacleType.stormCloud,
      ]) {
        expect(type.isGiantSmashable, isFalse,
            reason: '${type.name} is a force, not an object');
      }
    });

    test('it reaches more than the Black Hole vacuum', () {
      // A plane the size of a building plausibly bulldozes gates and scenery
      // that the vortex deliberately leaves alone.
      expect(ObstacleType.building.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.building.isGiantSmashable, isTrue);
      expect(ObstacleType.powerLine.isGiantSmashable, isTrue);
    });
  });

  group('the smash is tuned to read as an impact', () {
    test('debris is launched, spun, and cleaned up quickly', () {
      expect(GameConfig.giantSmashLaunchSpeed, greaterThan(0));
      expect(GameConfig.giantSmashSpinSpeed, isNot(0));
      expect(GameConfig.giantSmashFlightSeconds, greaterThan(0));
      // Short enough that wreckage never lingers in the play area.
      expect(GameConfig.giantSmashFlightSeconds, lessThan(1.5));
    });

    test('smashing pays a bounty', () {
      expect(GameConfig.giantSmashPoints, greaterThan(0));
    });
  });

  group('session + live state wiring', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('activating Giant Mode surfaces it to the frame cache', () {
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.activatePowerUp(PowerUpType.giant);
      notifier.setPowerUpTimer(
        PowerUpType.giant,
        GameConfig.powerUpActiveDuration(PowerUpType.giant),
      );

      final snapshot = LivePowerUpState();
      snapshot.syncFrom(container.read(gameSessionProvider));
      expect(snapshot.giantActive, isTrue);

      snapshot.reset();
      expect(snapshot.giantActive, isFalse);
    });

    test('it ends on its own timer like everything else', () {
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.activatePowerUp(PowerUpType.giant);
      notifier.setPowerUpTimer(
        PowerUpType.giant,
        GameConfig.powerUpActiveDuration(PowerUpType.giant),
      );

      final expired =
          notifier.tickPowerUpTimers(GameConfig.giantDuration + 0.1);

      expect(expired, contains(PowerUpType.giant));
      expect(container.read(gameSessionProvider).activePowerUps, isEmpty);
    });
  });
}
