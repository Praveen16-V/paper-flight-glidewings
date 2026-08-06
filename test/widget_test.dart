// Paper Flight — core utility + model smoke tests.
// Full Flame integration tests require a device/emulator.

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/core/utils/math_utils.dart';
import 'package:paper_flight/core/utils/noise.dart';
import 'package:paper_flight/core/utils/object_pool.dart';
import 'package:paper_flight/models/run_result.dart';
import 'package:paper_flight/models/settings_model.dart';

void main() {
  group('MathUtils', () {
    test('lerp midpoints', () {
      expect(MathUtils.lerp(0, 10, 0.5), 5);
      expect(MathUtils.lerp(0, 10, 0), 0);
      expect(MathUtils.lerp(0, 10, 1), 10);
    });

    test('remap', () {
      expect(MathUtils.remap(5, 0, 10, 0, 100), 50);
    });

    test('clamp', () {
      expect(MathUtils.clamp(5, 0, 10), 5);
      expect(MathUtils.clamp(-1, 0, 10), 0);
      expect(MathUtils.clamp(11, 0, 10), 10);
    });

    test('weightedPick respects zero weights', () {
      final picks = <int>{};
      for (int i = 0; i < 40; i++) {
        picks.add(MathUtils.weightedPick([1, 2, 3], [0, 1, 0]));
      }
      expect(picks, equals({2}));
    });

    test('lowPass moves toward target', () {
      final next = MathUtils.lowPass(0, 1, 0.5);
      expect(next, 0.5);
    });

    test('distance', () {
      expect(MathUtils.distance(0, 0, 3, 4), 5);
    });
  });

  group('ValueNoise', () {
    test('fbm returns finite values in roughly [-1,1]', () {
      final n = ValueNoise(seed: 42);
      for (double t = 0; t < 10; t += 0.5) {
        final v = n.fbm(1.2, t, octaves: 3);
        expect(v.isFinite, isTrue);
        expect(v.abs(), lessThan(2.0));
      }
    });

    test('deterministic with same seed', () {
      final a = ValueNoise(seed: 7).fbm(0.5, 1.0);
      final b = ValueNoise(seed: 7).fbm(0.5, 1.0);
      expect(a, b);
    });
  });

  group('ObjectPool', () {
    test('acquire / release reuses instances', () {
      var created = 0;
      final pool = ObjectPool<int>(
        create: () {
          created++;
          return created;
        },
        initialSize: 2,
      );
      expect(created, 2);
      final a = pool.acquire();
      final b = pool.acquire();
      expect(pool.available, 0);
      pool.release(a);
      pool.release(b);
      expect(pool.available, 2);
      final c = pool.acquire();
      expect(identical(c, a) || identical(c, b) || c == a || c == b, isTrue);
    });
  });

  group('Enums / GDD coverage', () {
    test('all biomes have display names', () {
      for (final b in Biome.values) {
        expect(b.displayName.isNotEmpty, isTrue);
      }
    });

    test('plane unlock costs match GDD MVP (3 planes)', () {
      expect(PlaneType.values.length, 3);
      expect(PlaneType.dart.unlockCost, 0);
      expect(PlaneType.glider.unlockCost, greaterThan(0));
      expect(PlaneType.stuntFold.unlockCost, greaterThan(PlaneType.glider.unlockCost));
    });

    test('power-up set matches GDD §7', () {
      expect(
        PowerUpType.values.map((e) => e.name).toSet(),
        containsAll(['shield', 'magnet', 'turboGust', 'slowMo', 'secondWind']),
      );
    });

    test('obstacle set matches GDD MVP', () {
      expect(ObstacleType.values.length, greaterThanOrEqualTo(5));
    });
  });

  group('GameConfig', () {
    test('scroll speed ramp is sane', () {
      expect(GameConfig.baseScrollSpeed, lessThan(GameConfig.maxScrollSpeed));
      expect(GameConfig.scrollAcceleration, greaterThan(0));
    });

    test('biome thresholds are ascending', () {
      expect(GameConfig.biomeBackyardEnd, lessThan(GameConfig.biomeCityEnd));
      expect(GameConfig.biomeCityEnd, lessThan(GameConfig.biomeStormEnd));
      expect(GameConfig.biomeStormEnd, lessThan(GameConfig.biomeMountainEnd));
      expect(GameConfig.biomeMountainEnd, lessThan(GameConfig.biomeNightEnd));
    });

    test('ad honeymoon and frequency cap', () {
      expect(GameConfig.interstitialHoneymoonRuns, greaterThanOrEqualTo(3));
      expect(GameConfig.interstitialFrequencyCap, greaterThanOrEqualTo(2));
    });
  });

  group('Models', () {
    test('RunResult effectiveCoins doubles', () {
      const r = RunResult(
        score: 100,
        distanceMeters: 50,
        coinsCollected: 10,
        nearMisses: 2,
        isNewHighScore: false,
        finalBiome: Biome.city,
        doubleCoinsApplied: true,
      );
      expect(r.effectiveCoins, 20);
    });

    test('SettingsModel round-trip', () {
      final s = SettingsModel(
        tiltSensitivity: 1.5,
        controlScheme: ControlScheme.touchZones,
        sfxEnabled: false,
      );
      final copy = SettingsModel.fromMap(s.toMap());
      expect(copy.tiltSensitivity, 1.5);
      expect(copy.controlScheme, ControlScheme.touchZones);
      expect(copy.sfxEnabled, isFalse);
    });
  });
}
