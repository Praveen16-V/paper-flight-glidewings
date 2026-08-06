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

  /// Runs since last interstitial was shown — used for frequency cap.
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

  /// Pending free shield for next run (from shop rewarded ad).
  @HiveField(14)
  bool pendingStartShield;

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
    this.pendingStartShield = false,
  }) : unlockedPlaneIndices =
            unlockedPlaneIndices ?? [0]; // dart always unlocked

  /// Returns a fresh default save for a new installation.
  factory SaveData.fresh() => SaveData();
}
