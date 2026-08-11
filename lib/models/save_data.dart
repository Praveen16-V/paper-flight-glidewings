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

  // ── Game Modes (Task 8) ───────────────────────────────────────────────────

  /// Seed of the last daily seeded flight the player started (0 = never).
  @HiveField(26)
  int dailyLastSeed;

  /// Whether today's single daily attempt has been consumed. Only meaningful
  /// while [dailyLastSeed] equals the current day's seed.
  @HiveField(27)
  bool dailyAttemptUsed;

  /// Best star rating per trial id (index = trial id, 0–3 stars).
  @HiveField(28)
  List<int> trialStars;

  /// Best distance (m) reached in Zen Flight.
  @HiveField(29)
  double zenBestDistanceMeters;

  /// Upgrade level per plane index (maps to PlaneType.index, range 1..3).
  @HiveField(30)
  List<int> planeUpgradeLevels;

  /// Player custom craft skin primary color hex.
  @HiveField(31)
  int customSkinPrimaryHex;

  /// Player custom craft skin accent color hex.
  @HiveField(32)
  int customSkinAccentHex;

  /// Player custom craft pattern stamp index (0 = stars, 1 = diamonds, 2 = hearts, 3 = lightning).
  @HiveField(33)
  int customSkinStamp;

  /// Persistent 0..1 weathering per PaperSkin index. Empty entries read as
  /// pristine so saves created before the wear system migrate safely.
  @HiveField(34)
  List<double> skinWearLevels;

  /// User-imported Custom Craft pattern image, normalized as base64 (no data
  /// URI prefix). Empty means the procedural stamp pattern is used instead.
  @HiveField(35)
  String customSkinPatternBase64;

  /// Player-facing name for the imported Custom Craft pattern.
  @HiveField(36)
  String customSkinPatternName;

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
    this.dailyLastSeed = 0,
    this.dailyAttemptUsed = false,
    List<int>? trialStars,
    this.zenBestDistanceMeters = 0,
    List<int>? planeUpgradeLevels,
    this.customSkinPrimaryHex = 0xFF4FC3F7,
    this.customSkinAccentHex = 0xFFFFD54F,
    this.customSkinStamp = 0,
    List<double>? skinWearLevels,
    this.customSkinPatternBase64 = '',
    this.customSkinPatternName = '',
  })  : unlockedPlaneIndices = unlockedPlaneIndices ?? [0],
        unlockedSkinIndices = unlockedSkinIndices ?? [0],
        dailyChallengeIds = dailyChallengeIds ?? [],
        dailyChallengeProgress = dailyChallengeProgress ?? [],
        dailyChallengeCompleted = dailyChallengeCompleted ?? [],
        dailyChallengeClaimed = dailyChallengeClaimed ?? [],
        weeklyChallengeIds = weeklyChallengeIds ?? [],
        weeklyChallengeProgress = weeklyChallengeProgress ?? [],
        weeklyChallengeCompleted = weeklyChallengeCompleted ?? [],
        weeklyChallengeClaimed = weeklyChallengeClaimed ?? [],
        trialStars = trialStars ?? [],
        planeUpgradeLevels = planeUpgradeLevels ?? List.filled(16, 1),
        skinWearLevels = skinWearLevels ?? [];

  /// Returns the current upgrade level (1..3) for a given plane index.
  int getPlaneLevel(int planeIndex) {
    if (planeIndex < 0 || planeIndex >= planeUpgradeLevels.length) return 1;
    return planeUpgradeLevels[planeIndex].clamp(1, 3);
  }

  /// Returns weathering for [skinIndex] (0 = pristine, 1 = veteran).
  double skinWearLevelFor(int skinIndex) {
    if (skinIndex < 0 || skinIndex >= skinWearLevels.length) return 0.0;
    return skinWearLevels[skinIndex].clamp(0.0, 1.0).toDouble();
  }

  /// Returns a fresh default save for a new installation.
  factory SaveData.fresh() => SaveData();

  /// Returns a deep copy of this SaveData instance.
  SaveData clone() {
    return SaveData(
      coins: coins,
      gems: gems,
      highScore: highScore,
      highDistanceMeters: highDistanceMeters,
      totalRuns: totalRuns,
      totalCoinsCollected: totalCoinsCollected,
      totalNearMisses: totalNearMisses,
      unlockedPlaneIndices: List<int>.from(unlockedPlaneIndices),
      equippedPlaneIndex: equippedPlaneIndex,
      adsRemoved: adsRemoved,
      runsSinceLastInterstitial: runsSinceLastInterstitial,
      isFirstSession: isFirstSession,
      lastDailyLoginMs: lastDailyLoginMs,
      dailyLoginStreak: dailyLoginStreak,
      unlockedSkinIndices: List<int>.from(unlockedSkinIndices),
      equippedSkinIndex: equippedSkinIndex,
      lastDailyChallengeMs: lastDailyChallengeMs,
      dailyChallengeIds: List<int>.from(dailyChallengeIds),
      dailyChallengeProgress: List<int>.from(dailyChallengeProgress),
      dailyChallengeCompleted: List<bool>.from(dailyChallengeCompleted),
      dailyChallengeClaimed: List<bool>.from(dailyChallengeClaimed),
      lastWeeklyChallengeMs: lastWeeklyChallengeMs,
      weeklyChallengeIds: List<int>.from(weeklyChallengeIds),
      weeklyChallengeProgress: List<int>.from(weeklyChallengeProgress),
      weeklyChallengeCompleted: List<bool>.from(weeklyChallengeCompleted),
      weeklyChallengeClaimed: List<bool>.from(weeklyChallengeClaimed),
      dailyLastSeed: dailyLastSeed,
      dailyAttemptUsed: dailyAttemptUsed,
      trialStars: List<int>.from(trialStars),
      zenBestDistanceMeters: zenBestDistanceMeters,
      planeUpgradeLevels: List<int>.from(planeUpgradeLevels),
      customSkinPrimaryHex: customSkinPrimaryHex,
      customSkinAccentHex: customSkinAccentHex,
      customSkinStamp: customSkinStamp,
      skinWearLevels: List<double>.from(skinWearLevels),
      customSkinPatternBase64: customSkinPatternBase64,
      customSkinPatternName: customSkinPatternName,
    );
  }
}
