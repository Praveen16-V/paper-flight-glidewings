// Unit tests for Task 8 — game modes: daily seed derivation, trial course
// integrity, star evaluation and unlock progression.

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/models/trial_definition.dart';
import 'package:paper_flight/services/daily_seed_service.dart';

void main() {
  group('DailySeedService', () {
    test('same UTC day always yields the same seed', () {
      final a = DailySeedService.seedForDate(DateTime.utc(2026, 8, 7, 1));
      final b = DailySeedService.seedForDate(DateTime.utc(2026, 8, 7, 23));
      expect(a, b);
    });

    test('different days yield different seeds', () {
      final a = DailySeedService.seedForDate(DateTime.utc(2026, 8, 7));
      final b = DailySeedService.seedForDate(DateTime.utc(2026, 8, 8));
      expect(a, isNot(b));
    });

    test('seed is stable across local timezones (UTC-based)', () {
      // Local dates in +5:30 vs UTC — same UTC calendar day → same seed.
      final inChennai = DateTime(2026, 8, 8, 0, 30); // 2026-08-07 19:00 UTC
      final inUtc = DateTime.utc(2026, 8, 7, 19);
      expect(
        DailySeedService.seedForDate(inChennai),
        DailySeedService.seedForDate(inUtc),
      );
    });

    test('next reset is the following UTC midnight', () {
      final reset = DailySeedService.nextResetUtc(DateTime.utc(2026, 8, 7, 10));
      expect(reset, DateTime.utc(2026, 8, 8));
    });
  });

  group('TrialPool', () {
    test('exactly six handcrafted courses', () {
      expect(TrialPool.all.length, 6);
      final ids = TrialPool.all.map((t) => t.id).toSet();
      expect(ids, {0, 1, 2, 3, 4, 5});
    });

    test('every course has at least one scripted element', () {
      for (final t in TrialPool.all) {
        expect(t.steps, isNotEmpty, reason: t.title);
      }
    });

    test('declared coin totals match the planted coin counts', () {
      for (final t in TrialPool.all) {
        expect(t.countCoins(), t.totalCoins,
            reason: '${t.title} coin total mismatch');
      }
    });

    test('course end is after the last element plus margin', () {
      for (final t in TrialPool.all) {
        final last =
            t.steps.map((s) => s.atMeters).reduce((a, b) => a > b ? a : b);
        expect(t.courseEndMeters, greaterThan(last));
      }
    });

    test('time trials have par and timeRemaining star metric', () {
      for (final t in TrialPool.all) {
        if (t.starMetric == TrialStarMetric.timeRemaining) {
          expect(t.parSeconds, isNotNull, reason: t.title);
          expect(t.starThresholds.length, 3);
        }
      }
    });

    test('coin trials have no par and use coin-percent stars', () {
      final canyon =
          TrialPool.all.firstWhere((t) => t.id == 1);
      expect(canyon.parSeconds, isNull);
      expect(canyon.starMetric, TrialStarMetric.coinsPercent);
    });
  });

  group('TrialDefinition.starsFor', () {
    test('time remaining thresholds award 1/2/3 stars', () {
      final t = TrialPool.byId(0)!; // thresholds [0, 2, 5]
      expect(t.starsFor(0.0), 1);
      expect(t.starsFor(2.0), 2);
      expect(t.starsFor(5.0), 3);
      expect(t.starsFor(99.0), 3);
    });

    test('coin percentage thresholds award stars', () {
      final t = TrialPool.byId(1)!; // thresholds [0.6, 0.85, 1.0]
      expect(t.starsFor(0.59), 1);
      expect(t.starsFor(0.85), 2);
      expect(t.starsFor(1.0), 3);
    });
  });

  group('Trial progression', () {
    test('trial unlocks after one star on the previous course', () {
      final first = TrialPool.byId(0)!;
      final second = TrialPool.byId(1)!;
      expect(first.isUnlockedBy(0), isTrue); // first is always open
      expect(second.isUnlockedBy(0), isFalse);
      expect(second.isUnlockedBy(1), isTrue);
    });

    test('every trial pins a valid biome', () {
      for (final t in TrialPool.all) {
        expect(Biome.values, contains(t.biome), reason: t.title);
      }
    });
  });
}
