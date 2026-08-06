import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/save_data.dart';
import '../services/persistence_service.dart';

/// Notifier that owns the canonical SaveData state.
/// UI reads from this; game systems call methods to mutate and persist.
class SaveDataNotifier extends Notifier<SaveData> {
  @override
  SaveData build() {
    return PersistenceService.instance.loadSave();
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

  // ── Unlocks ──────────────────────────────────────────────────────────────

  bool isPlaneUnlocked(int planeIndex) =>
      state.unlockedPlaneIndices.contains(planeIndex);

  Future<bool> unlockPlane(int planeIndex, int cost) async {
    if (!isPlaneUnlocked(planeIndex) && state.coins >= cost) {
      state = await PersistenceService.instance.updateSave((s) {
        s.coins -= cost;
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

  // ── Pre-run shield (shop rewarded ad) ──────────────────────────────────

  Future<void> setPendingStartShield(bool value) async {
    state = await PersistenceService.instance.updateSave((s) {
      s.pendingStartShield = value;
      return s;
    });
  }

  Future<void> clearPendingStartShield() async {
    if (!state.pendingStartShield) return;
    await setPendingStartShield(false);
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
}

final saveDataProvider = NotifierProvider<SaveDataNotifier, SaveData>(
  SaveDataNotifier.new,
);
