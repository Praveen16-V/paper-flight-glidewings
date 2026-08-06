import 'package:hive_flutter/hive_flutter.dart';

part 'save_data.g.dart';

/// Root persistent save file — stored in a single Hive box entry.
/// Covers coins, gems, unlocks, high scores, run count, and settings.
@HiveType(typeId: 0)
class SaveData extends HiveObject {
  @HiveField(0)
  int coins;

  @HiveField(1)
  int gems;

  @HiveField(2)
  int highScore;

  @HiveField(3)
  double highDistanceMeters;

  @HiveField(4)
  int totalRuns;

  @HiveField(5)
  int totalCoinsCollected;

  @HiveField(6)
  int totalNearMisses;

  /// List of unlocked PlaneType indices (maps to PlaneType.index).
  @HiveField(7)
  List<int> unlockedPlaneIndices;

  /// Currently equipped plane index.
  @HiveField(8)
  int equippedPlaneIndex;

  /// Whether ads have been removed via IAP.
  @HiveField(9)
  bool adsRemoved;

  /// Total runs played — used for interstitial honeymoon period.
  @HiveField(10)
  int runsSinceLastInterstitial;

  /// Whether this is the user's first ever session.
  @HiveField(11)
  bool isFirstSession;

  /// Timestamp of last daily login reward claim (milliseconds since epoch).
  @HiveField(12)
  int lastDailyLoginMs;

  /// Current daily login streak count.
  @HiveField(13)
  int dailyLoginStreak;

  // ── Paper Skins (Task 7) ──────────────────────────────────────────────────

  /// Unlocked PaperSkin indices.
  @HiveField(14)
  List<int> unlockedSkinIndices;

  /// Equipped PaperSkin index.
  @HiveField(15)
  int equippedSkinIndex;

  // ── Daily Challenges ──────────────────────────────────────────────────────

  /// Midnight epoch ms of the active daily set.
  @HiveField(16)
  int lastDailyChallengeMs;

  /// Active daily challenge definition ids (size = dailyChallengeCount).
  @HiveField(17)
  List<int> dailyChallengeIds;

  /// Progress counters parallel to [dailyChallengeIds].
  @HiveField(18)
  List<int> dailyChallengeProgress;

  /// Completed flags parallel to [dailyChallengeIds].
  @HiveField(19)
  List<bool> dailyChallengeCompleted;

  /// Claimed flags parallel to [dailyChallengeIds].
  @HiveField(20)
  List<bool> dailyChallengeClaimed;

  // ── Weekly Challenges ─────────────────────────────────────────────────────

  /// Monday midnight epoch ms of the active weekly set.
  @HiveField(21)
  int lastWeeklyChallengeMs;

  /// Active weekly challenge definition ids.
  @HiveField(22)
  List<int> weeklyChallengeIds;

  /// Progress counters parallel to [weeklyChallengeIds].
  @HiveField(23)
  List<int> weeklyChallengeProgress;

  /// Completed flags parallel to [weeklyChallengeIds].
  @HiveField(24)
  List<bool> weeklyChallengeCompleted;

  /// Claimed flags parallel to [weeklyChallengeIds].
  @HiveField(25)
  List<bool> weeklyChallengeClaimed;

  SaveData({
    this.coins = 0,
    this.gems = 0,
    this.highScore = 0,
    this.highDistanceMeters = 0,
    this.totalRuns = 0,
    this.totalCoinsCollected = 0,
    this.totalNearMisses = 0,
    List<int>? unlockedPlaneIndices,
    this.equippedPlaneIndex = 0, // PlaneType.dart is index 0 — always free
    this.adsRemoved = false,
    this.runsSinceLastInterstitial = 0,
    this.isFirstSession = true,
    this.lastDailyLoginMs = 0,
    this.dailyLoginStreak = 0,
    List<int>? unlockedSkinIndices,
    this.equippedSkinIndex = 0, // PaperSkin.plain is index 0 — always free
    this.lastDailyChallengeMs = 0,
    List<int>? dailyChallengeIds,
    List<int>? dailyChallengeProgress,
    List<bool>? dailyChallengeCompleted,
    List<bool>? dailyChallengeClaimed,
    this.lastWeeklyChallengeMs = 0,
    List<int>? weeklyChallengeIds,
    List<int>? weeklyChallengeProgress,
    List<bool>? weeklyChallengeCompleted,
    List<bool>? weeklyChallengeClaimed,
  })  : unlockedPlaneIndices = unlockedPlaneIndices ?? [0],
        unlockedSkinIndices = unlockedSkinIndices ?? [0],
        dailyChallengeIds = dailyChallengeIds ?? [],
        dailyChallengeProgress = dailyChallengeProgress ?? [],
        dailyChallengeCompleted = dailyChallengeCompleted ?? [],
        dailyChallengeClaimed = dailyChallengeClaimed ?? [],
        weeklyChallengeIds = weeklyChallengeIds ?? [],
        weeklyChallengeProgress = weeklyChallengeProgress ?? [],
        weeklyChallengeCompleted = weeklyChallengeCompleted ?? [],
        weeklyChallengeClaimed = weeklyChallengeClaimed ?? [];

  /// Returns a fresh default save for a new installation.
  factory SaveData.fresh() => SaveData();
}
