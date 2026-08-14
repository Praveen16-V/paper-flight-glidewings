import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/live_powerup_state.dart';
import 'package:paper_flight/providers/game_session_provider.dart';

void main() {
  group('power-up durations are per-type and capped for charge bursts', () {
    test('empowered bursts always use the empowered duration', () {
      for (final type in PowerUpType.values) {
        expect(
          GameConfig.powerUpActiveDuration(type, empowered: true),
          GameConfig.empoweredPowerUpBurstDuration,
        );
      }
    });

    test('normal bursts never exceed the quick tactical length', () {
      for (final type in PowerUpType.values) {
        expect(
          GameConfig.powerUpActiveDuration(type, empowered: false),
          lessThanOrEqualTo(GameConfig.chargePowerUpBurstDuration),
        );
      }
    });

    test('short declared durations stay short instead of inflating to the cap',
        () {
      expect(
        GameConfig.powerUpActiveDuration(PowerUpType.turboDash,
            empowered: false),
        GameConfig.turboDashDuration,
      );
      expect(
        GameConfig.powerUpActiveDuration(PowerUpType.blackHole,
            empowered: false),
        GameConfig.blackHoleDuration,
      );
    });
  });

  group('Black Hole is a real vacuum', () {
    test('only small individual hazards are vacuumable', () {
      expect(ObstacleType.bird.isBlackHoleVacuumable, isTrue);
      expect(ObstacleType.drone.isBlackHoleVacuumable, isTrue);
      expect(ObstacleType.kite.isBlackHoleVacuumable, isTrue);
      expect(ObstacleType.fireworks.isBlackHoleVacuumable, isTrue);
      expect(ObstacleType.weatherBalloon.isBlackHoleVacuumable, isTrue);
      expect(ObstacleType.hotAirBalloon.isBlackHoleVacuumable, isTrue);

      // Gates, bosses, area hazards and oncoming traffic stay immune.
      expect(ObstacleType.powerLine.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.building.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.clothesline.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.paperDragon.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.tornado.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.lightningStrike.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.meteorShower.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.flockMigration.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.whaleBreach.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.trafficPlane.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.treeBranch.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.windTurbine.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.stormCloud.isBlackHoleVacuumable, isFalse);
      expect(ObstacleType.windsock.isBlackHoleVacuumable, isFalse);
    });

    test('swallow happens outside collision range but inside the pull radius',
        () {
      expect(
        GameConfig.blackHoleSwallowDistance,
        lessThan(GameConfig.blackHoleObstaclePullRadius),
      );
      expect(GameConfig.blackHoleSwallowDistance, greaterThan(0));
      expect(
        GameConfig.blackHoleCoinCollectDistance,
        lessThan(GameConfig.blackHoleCoinPullRadius),
      );
    });
  });

  group('Turbo Dash is an actual thrust surge', () {
    test('the dash accelerates the world scroll', () {
      expect(GameConfig.turboDashWorldSpeedMultiplier, greaterThan(1.0));
    });

    test('Time Dash still runs slower than plain Slow-Mo', () {
      expect(
        GameConfig.timeDashWorldSpeedMultiplier,
        lessThan(GameConfig.slowMoPowerUpMultiplier),
      );
    });
  });

  group('shield stacking', () {
    test('a pickup adds to existing charges but stays capped', () {
      expect(GameConfig.shieldMaxStackedCharges, greaterThanOrEqualTo(2));
    });
  });

  group('corrupted pickups are gated behind the opening biomes', () {
    test('no bargains before the city ends', () {
      expect(GameConfig.corruptedPowerUpStartMeters,
          GameConfig.biomeCityEnd);
      expect(GameConfig.corruptedPowerUpStartMeters,
          greaterThanOrEqualTo(GameConfig.biomeBackyardEnd));
    });
  });

  group('boss pacing', () {
    test('the Paper Dragon has a positive re-spawn cooldown', () {
      expect(GameConfig.paperDragonSpawnCooldown, greaterThan(0));
    });
  });

  group('elite rates stay readable surprises', () {
    test('golden bird and elite variants are tuned below their old values',
        () {
      expect(GameConfig.goldenBirdEliteChance, lessThanOrEqualTo(0.10));
      expect(GameConfig.armedDroneEliteChance, lessThanOrEqualTo(0.25));
      expect(GameConfig.thicketBranchEliteChance, lessThanOrEqualTo(0.25));
    });
  });

  group('LivePowerUpState snapshot', () {
    test('mirrors the session flags on sync and clears on reset', () {
      final snapshot = LivePowerUpState();
      const active = GameSessionState(
        activePowerUps: {
          PowerUpType.ghost,
          PowerUpType.blackHole,
          PowerUpType.turboDash,
          PowerUpType.slowMo,
          PowerUpType.coinRush,
          PowerUpType.doubleScore,
          PowerUpType.windCaller,
          PowerUpType.magnet,
        },
        activeEmpoweredPowerUps: {PowerUpType.magnet},
        activeCorruptedPowerUps: {
          CorruptedPowerUpType.cursedMagnet,
          CorruptedPowerUpType.unstableGhost,
        },
        shieldActive: true,
      );

      snapshot.syncFrom(active);
      expect(snapshot.ghostActive, isTrue);
      expect(snapshot.blackHoleActive, isTrue);
      expect(snapshot.turboDashActive, isTrue);
      expect(snapshot.slowMoActive, isTrue);
      expect(snapshot.coinRushActive, isTrue);
      expect(snapshot.doubleScoreActive, isTrue);
      expect(snapshot.windCallerActive, isTrue);
      expect(snapshot.magnetActive, isTrue);
      expect(snapshot.magnetEmpowered, isTrue);
      expect(snapshot.cursedMagnetActive, isTrue);
      expect(snapshot.unstableGhostActive, isTrue);
      expect(snapshot.shieldActive, isTrue);

      snapshot.reset();
      expect(snapshot.ghostActive, isFalse);
      expect(snapshot.blackHoleActive, isFalse);
      expect(snapshot.turboDashActive, isFalse);
      expect(snapshot.slowMoActive, isFalse);
      expect(snapshot.coinRushActive, isFalse);
      expect(snapshot.doubleScoreActive, isFalse);
      expect(snapshot.windCallerActive, isFalse);
      expect(snapshot.magnetActive, isFalse);
      expect(snapshot.magnetEmpowered, isFalse);
      expect(snapshot.cursedMagnetActive, isFalse);
      expect(snapshot.unstableGhostActive, isFalse);
      expect(snapshot.shieldActive, isFalse);
      expect(snapshot.magnetLevel, 1);
    });
  });
}
