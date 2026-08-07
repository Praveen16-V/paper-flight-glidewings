import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/game_enums.dart';
import '../models/save_data.dart';
import '../models/challenge_definitions.dart';
import '../services/persistence_service.dart';

/// Notifier that owns the canonical SaveData state.
/// UI reads from this; game systems call methods to mutate and persist.
class SaveDataNotifier extends Notifier<SaveData> {
  @override
  SaveData build() {
    final save = PersistenceService.instance.loadSave();
    // Lazily ensure challenges are initialized; defer writing until needed
    // but synchronously expose generated placeholders if empty.
    Future.microtask(() => _ensureChallengesInitialized());
    return save;
  }

  // ── Currency ────────────────────────────────────────────────────────────

  Future<void> addCoins(int amount) async {
    state = await PersistenceService.instance.updateSave((s) {
      s.coins += amount;
      s.totalCoinsCollected += amount;
      return s;
    });
  }

  Future<void> spendCoins(int amount) async {
    if (state.coins < amount) return;
    state = await PersistenceService.instance.updateSave((s) {
      s.coins -= amount;
      return s;
    });
  }

  Future<void> addGems(int amount) async {
    state = await PersistenceService.instance.updateSave((s) {
      s.gems += amount;
      return s;
    });
  }

  Future<void> spendGems(int amount) async {
    if (state.gems < amount) return;
    state = await PersistenceService.instance.updateSave((s) {
      s.gems -= amount;
      return s;
    });
  }

  // ── Scores / Stats ───────────────────────────────────────────────────────

  /// Called at run end. Updates high score, run count, near-miss tally.
  Future<bool> recordRunResult({
    required int score,
    required double distanceMeters,
    required int coinsEarned,
    required int nearMisses,
  }) async {
    bool newHighScore = false;
    state = await PersistenceService.instance.updateSave((s) {
      s.totalRuns++;
      s.totalCoinsCollected += coinsEarned;
      s.coins += coinsEarned;
      s.totalNearMisses += nearMisses;
      if (score > s.highScore) {
        s.highScore = score;
        newHighScore = true;
      }
      if (distanceMeters > s.highDistanceMeters) {
        s.highDistanceMeters = distanceMeters;
      }
      s.runsSinceLastInterstitial++;
      s.isFirstSession = false;
      return s;
    });
    return newHighScore;
  }

  // ── Game Modes (Task 8) ──────────────────────────────────────────────────

  /// Consumes today's Daily Seeded Flight attempt. Called the moment a daily
  /// run starts — quitting mid-run still counts as the attempt.
  Future<void> markDailyAttempt({required int seed}) async {
    state = await PersistenceService.instance.updateSave((s) {
      s.dailyLastSeed = seed;
      s.dailyAttemptUsed = true;
      return s;
    });
  }

  /// Records the best star rating for a Precision Trial (progression only —
  /// trials award no coins). Returns true when a new personal best was set.
  Future<bool> recordTrialStars({
    required int trialId,
    required int stars,
  }) async {
    var isNewBest = false;
    state = await PersistenceService.instance.updateSave((s) {
      final list = List<int>.from(s.trialStars);
      while (list.length <= trialId) {
        list.add(0);
      }
      if (stars > list[trialId]) {
        list[trialId] = stars;
        isNewBest = true;
      }
      s.trialStars = list;
      return s;
    });
    return isNewBest;
  }

  /// Best distance reached in a Zen Flight (a personal stat only — Zen never
  /// touches the coin economy).
  Future<void> recordZenRun(double distanceMeters) async {
    state = await PersistenceService.instance.updateSave((s) {
      if (distanceMeters > s.zenBestDistanceMeters) {
        s.zenBestDistanceMeters = distanceMeters;
      }
      return s;
    });
  }

  /// Star rating (0–3) earned on a trial, or 0 if never played.
  int trialBestStars(int trialId) {
    if (trialId < 0 || trialId >= state.trialStars.length) return 0;
    return state.trialStars[trialId];
  }

  // ── Plane Unlocks ───────────────────────────────────────────────────────

  bool isPlaneUnlocked(int planeIndex) =>
      state.unlockedPlaneIndices.contains(planeIndex);

  Future<bool> unlockPlane(int planeIndex, int cost, {int gemCost = 0}) async {
    if (!isPlaneUnlocked(planeIndex) &&
        state.coins >= cost &&
        state.gems >= gemCost) {
      state = await PersistenceService.instance.updateSave((s) {
        s.coins -= cost;
        s.gems -= gemCost;
        if (!s.unlockedPlaneIndices.contains(planeIndex)) {
          s.unlockedPlaneIndices.add(planeIndex);
        }
        return s;
      });
      return true;
    }
    return false;
  }

  Future<void> equipPlane(int planeIndex) async {
    if (!isPlaneUnlocked(planeIndex)) return;
    state = await PersistenceService.instance.updateSave((s) {
      s.equippedPlaneIndex = planeIndex;
      return s;
    });
  }

  // ── Skin Unlocks ─────────────────────────────────────────────────────────

  bool isSkinUnlocked(int skinIndex) =>
      state.unlockedSkinIndices.contains(skinIndex);

  Future<bool> unlockSkin(int skinIndex, int coinCost, int gemCost) async {
    if (!isSkinUnlocked(skinIndex) &&
        state.coins >= coinCost &&
        state.gems >= gemCost) {
      state = await PersistenceService.instance.updateSave((s) {
        s.coins -= coinCost;
        s.gems -= gemCost;
        if (!s.unlockedSkinIndices.contains(skinIndex)) {
          s.unlockedSkinIndices.add(skinIndex);
        }
        return s;
      });
      return true;
    }
    return false;
  }

  Future<void> equipSkin(int skinIndex) async {
    if (!isSkinUnlocked(skinIndex)) return;
    state = await PersistenceService.instance.updateSave((s) {
      s.equippedSkinIndex = skinIndex;
      return s;
    });
  }

  // ── Ads ──────────────────────────────────────────────────────────────────

  Future<void> setAdsRemoved() async {
    state = await PersistenceService.instance.updateSave((s) {
      s.adsRemoved = true;
      return s;
    });
  }

  void resetInterstitialCounter() {
    PersistenceService.instance.updateSave((s) {
      s.runsSinceLastInterstitial = 0;
      return s;
    }).then((updated) => state = updated);
  }

  // ── Daily Login ──────────────────────────────────────────────────────────

  /// Returns the reward amount (in coins) if a new day has been claimed.
  /// Returns 0 if already claimed today.
  Future<int> claimDailyLoginReward() async {
    final now = DateTime.now();
    final lastClaim =
        DateTime.fromMillisecondsSinceEpoch(state.lastDailyLoginMs);
    final daysSince = now.difference(lastClaim).inDays;

    if (daysSince < 1) return 0; // already claimed today

    int reward = 0;
    state = await PersistenceService.instance.updateSave((s) {
      // Streak resets if missed more than 1 day
      if (daysSince > 1) s.dailyLoginStreak = 0;
      s.dailyLoginStreak =
          (s.dailyLoginStreak % 7) + 1; // cycles 1–7
      reward = _dailyRewardForDay(s.dailyLoginStreak);
      s.coins += reward;
      s.lastDailyLoginMs = now.millisecondsSinceEpoch;
      return s;
    });
    return reward;
  }

  static int _dailyRewardForDay(int day) {
    // Escalating rewards over 7-day cycle
    const rewards = [50, 75, 100, 100, 150, 200, 300];
    return rewards[(day - 1).clamp(0, 6)];
  }

  // ── Challenges ───────────────────────────────────────────────────────────

  Future<void> _ensureChallengesInitialized() async {
    final now = DateTime.now();
    bool needsWrite = false;
    final current = state;

    // Daily check: if no daily or last daily is not today
    final todayMidnight = DateTime(now.year, now.month, now.day);
    if (current.dailyChallengeIds.isEmpty ||
        current.lastDailyChallengeMs == 0 ||
        DateTime.fromMillisecondsSinceEpoch(current.lastDailyChallengeMs)
                .difference(todayMidnight)
                .inDays !=
            0) {
      // Need to roll daily
      final seed = todayMidnight.millisecondsSinceEpoch;
      final ids = _pickDailyIds(seed);
      state = await PersistenceService.instance.updateSave((s) {
        s.lastDailyChallengeMs = todayMidnight.millisecondsSinceEpoch;
        s.dailyChallengeIds = ids;
        s.dailyChallengeProgress = List.filled(ids.length, 0);
        s.dailyChallengeCompleted = List.filled(ids.length, false);
        s.dailyChallengeClaimed = List.filled(ids.length, false);
        return s;
      });
      needsWrite = true;
    }

    // Weekly check: Monday midnight
    final monday = _mondayMidnight(now);
    if (current.weeklyChallengeIds.isEmpty ||
        current.lastWeeklyChallengeMs == 0 ||
        DateTime.fromMillisecondsSinceEpoch(current.lastWeeklyChallengeMs)
                .difference(monday)
                .inDays !=
            0) {
      final seed = monday.millisecondsSinceEpoch;
      final ids = _pickWeeklyIds(seed);
      state = await PersistenceService.instance.updateSave((s) {
        s.lastWeeklyChallengeMs = monday.millisecondsSinceEpoch;
        s.weeklyChallengeIds = ids;
        s.weeklyChallengeProgress = List.filled(ids.length, 0);
        s.weeklyChallengeCompleted = List.filled(ids.length, false);
        s.weeklyChallengeClaimed = List.filled(ids.length, false);
        return s;
      });
      needsWrite = true;
    }

    if (!needsWrite && (current.dailyChallengeIds.isEmpty || current.weeklyChallengeIds.isEmpty)) {
      // Fallback force init
      await _forceInitChallenges();
    }
  }

  Future<void> _forceInitChallenges() async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final monday = _mondayMidnight(now);
    state = await PersistenceService.instance.updateSave((s) {
      if (s.dailyChallengeIds.isEmpty) {
        s.lastDailyChallengeMs = todayMidnight.millisecondsSinceEpoch;
        s.dailyChallengeIds = _pickDailyIds(todayMidnight.millisecondsSinceEpoch);
        s.dailyChallengeProgress = List.filled(s.dailyChallengeIds.length, 0);
        s.dailyChallengeCompleted = List.filled(s.dailyChallengeIds.length, false);
        s.dailyChallengeClaimed = List.filled(s.dailyChallengeIds.length, false);
      }
      if (s.weeklyChallengeIds.isEmpty) {
        s.lastWeeklyChallengeMs = monday.millisecondsSinceEpoch;
        s.weeklyChallengeIds = _pickWeeklyIds(monday.millisecondsSinceEpoch);
        s.weeklyChallengeProgress = List.filled(s.weeklyChallengeIds.length, 0);
        s.weeklyChallengeCompleted = List.filled(s.weeklyChallengeIds.length, false);
        s.weeklyChallengeClaimed = List.filled(s.weeklyChallengeIds.length, false);
      }
      return s;
    });
  }

  DateTime _mondayMidnight(DateTime now) {
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final weekday = now.weekday; // 1 Mon
    return todayMidnight.subtract(Duration(days: weekday - 1));
  }

  List<int> _pickDailyIds(int seed) {
    final rnd = Random(seed);
    final pool = List<int>.generate(ChallengePool.daily.length, (i) => ChallengePool.daily[i].id);
    pool.shuffle(rnd);
    // Always include the 3 showcase challenges 0,1,2 for first days? Otherwise random
    // For deterministic showcase, keep first 3 if seed mod 7 ==0 etc. Simplify: random 3.
    final picked = pool.take(3).toList();
    // Ensure showcase trio appears at least 50% of time for demo purposes
    // If none of 0,1,2 present and rnd.nextDouble()<0.5, inject one
    if (!picked.any((id) => id <= 2) && rnd.nextDouble() < 0.5) {
      picked[0] = rnd.nextInt(3); // replace first with 0-2
    }
    return picked;
  }

  List<int> _pickWeeklyIds(int seed) {
    final rnd = Random(seed);
    final pool = List<int>.generate(ChallengePool.weekly.length, (i) => ChallengePool.weekly[i].id);
    pool.shuffle(rnd);
    return pool.take(3).toList();
  }

  /// Force refresh check (call on app resume or screen open).
  Future<void> refreshChallengesIfNeeded() async {
    await _ensureChallengesInitialized();
    // Also verify we have progress arrays matching ids
    if (state.dailyChallengeIds.length != state.dailyChallengeProgress.length) {
      state = await PersistenceService.instance.updateSave((s) {
        s.dailyChallengeProgress = List.filled(s.dailyChallengeIds.length, 0);
        s.dailyChallengeCompleted = List.filled(s.dailyChallengeIds.length, false);
        s.dailyChallengeClaimed = List.filled(s.dailyChallengeIds.length, false);
        return s;
      });
    }
    if (state.weeklyChallengeIds.length != state.weeklyChallengeProgress.length) {
      state = await PersistenceService.instance.updateSave((s) {
        s.weeklyChallengeProgress = List.filled(s.weeklyChallengeIds.length, 0);
        s.weeklyChallengeCompleted = List.filled(s.weeklyChallengeIds.length, false);
        s.weeklyChallengeClaimed = List.filled(s.weeklyChallengeIds.length, false);
        return s;
      });
    }
  }

  /// Record run stats into challenges. Call at end of each run.
  Future<void> updateChallengesForRun({
    required int thermalsEntered,
    required int maxCombo,
    required Biome biomeForMaxCombo,
    required int maxComboInStorm,
    required int buildingGapsPassed,
    required bool usedPowerUp,
    required int coinsCollected,
    required int nearMisses,
    required double distanceMeters,
    required int powerUpsUsed,
  }) async {
    await refreshChallengesIfNeeded();

    bool changed = false;
    state = await PersistenceService.instance.updateSave((s) {
      void apply(List<int> ids, List<int> prog, List<bool> comp) {
        for (int i = 0; i < ids.length; i++) {
          final def = ChallengePool.byId(ids[i]);
          if (def == null) continue;
          if (comp[i]) continue; // already completed
          int newVal = prog[i];
          bool markComplete = false;

          switch (def.type) {
            case ChallengeType.rideThermalsSingleRun:
              // best single-run value
              newVal = thermalsEntered > newVal ? thermalsEntered : newVal;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.rideThermalsTotal:
              newVal += thermalsEntered;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.coinComboInBiome:
              // Check if this run hit target in required biome (or any if biome==null)
              bool hit = false;
              if (def.biome != null) {
                // Storm-specific tracking uses dedicated storm max
                if (def.biome == Biome.storm) {
                  if (maxComboInStorm >= def.target) hit = true;
                } else {
                  if (biomeForMaxCombo == def.biome && maxCombo >= def.target) hit = true;
                }
              } else {
                if (maxCombo >= def.target) hit = true;
              }
              if (hit) {
                newVal = def.target;
                markComplete = true;
              } else {
                // keep best — for storm use storm-specific, else overall
                final relevant = (def.biome == Biome.storm) ? maxComboInStorm : maxCombo;
                if (relevant > newVal) newVal = relevant;
                if (def.biome == null && newVal >= def.target) markComplete = true;
              }
              break;
            case ChallengeType.skyscraperGapsNoPowerUp:
              if (!usedPowerUp) {
                newVal = buildingGapsPassed > newVal ? buildingGapsPassed : newVal;
                if (newVal >= def.target) markComplete = true;
              }
              break;
            case ChallengeType.collectCoinsSingleRun:
              newVal = coinsCollected > newVal ? coinsCollected : newVal;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.collectCoinsTotal:
              newVal += coinsCollected;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.nearMissesSingleRun:
              newVal = nearMisses > newVal ? nearMisses : newVal;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.nearMissesTotal:
              newVal += nearMisses;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.travelDistanceSingleRun:
              final d = distanceMeters.toInt();
              newVal = d > newVal ? d : newVal;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.travelDistanceTotal:
              newVal += distanceMeters.toInt();
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.surviveRuns:
              newVal += 1;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.usePowerUps:
              newVal += powerUpsUsed;
              if (newVal >= def.target) markComplete = true;
              break;
            case ChallengeType.buildingGapsTotal:
              newVal += buildingGapsPassed;
              if (newVal >= def.target) markComplete = true;
              break;
          }

          // Clamp
          if (newVal > def.target) newVal = def.target;
          if (newVal != prog[i]) {
            prog[i] = newVal;
            changed = true;
          }
          if (markComplete && !comp[i]) {
            comp[i] = true;
            changed = true;
          }
        }
      }

      apply(s.dailyChallengeIds, s.dailyChallengeProgress, s.dailyChallengeCompleted);
      apply(s.weeklyChallengeIds, s.weeklyChallengeProgress, s.weeklyChallengeCompleted);

      return s;
    });
  }

  /// Claim reward for a completed challenge. Returns coins/gems awarded or 0 if not claimable.
  Future<(int coins, int gems)> claimChallengeReward({
    required ChallengePeriod period,
    required int index,
  }) async {
    final save = state;
    final ids = period == ChallengePeriod.daily ? save.dailyChallengeIds : save.weeklyChallengeIds;
    final completed = period == ChallengePeriod.daily ? save.dailyChallengeCompleted : save.weeklyChallengeCompleted;
    final claimed = period == ChallengePeriod.daily ? save.dailyChallengeClaimed : save.weeklyChallengeClaimed;

    if (index < 0 || index >= ids.length) return (0, 0);
    if (!completed[index]) return (0, 0);
    if (claimed[index]) return (0, 0);

    final def = ChallengePool.byId(ids[index]);
    if (def == null) return (0, 0);

    state = await PersistenceService.instance.updateSave((s) {
      if (period == ChallengePeriod.daily) {
        s.dailyChallengeClaimed[index] = true;
        s.coins += def.rewardCoins;
        s.gems += def.rewardGems;
      } else {
        s.weeklyChallengeClaimed[index] = true;
        s.coins += def.rewardCoins;
        s.gems += def.rewardGems;
      }
      return s;
    });

    return (def.rewardCoins, def.rewardGems);
  }

  /// Quick helper to get reward for claim all.
  Future<int> claimAllCompleted() async {
    int totalCoins = 0;
    int totalGems = 0;
    final save = state;
    for (int i = 0; i < save.dailyChallengeIds.length; i++) {
      if (save.dailyChallengeCompleted[i] && !save.dailyChallengeClaimed[i]) {
        final res = await claimChallengeReward(period: ChallengePeriod.daily, index: i);
        totalCoins += res.$1;
        totalGems += res.$2;
      }
    }
    for (int i = 0; i < save.weeklyChallengeIds.length; i++) {
      if (save.weeklyChallengeCompleted[i] && !save.weeklyChallengeClaimed[i]) {
        final res = await claimChallengeReward(period: ChallengePeriod.weekly, index: i);
        totalCoins += res.$1;
        totalGems += res.$2;
      }
    }
    return totalCoins + totalGems * 100;
  }
}

final saveDataProvider = NotifierProvider<SaveDataNotifier, SaveData>(
  SaveDataNotifier.new,
);
