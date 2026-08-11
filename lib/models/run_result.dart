import '../core/enums/game_enums.dart';

/// Immutable snapshot of a single completed run — passed to GameOverScreen.
class RunResult {
  const RunResult({
    required this.score,
    required this.distanceMeters,
    required this.coinsCollected,
    required this.nearMisses,
    required this.isNewHighScore,
    required this.finalBiome,
    this.wasRevived = false,
    this.doubleCoinsApplied = false,
    this.runDurationSeconds = 0,
    this.crashCause = 'unknown',
    this.maxCombo = 0,
    this.powerUpsUsed = 0,
    this.lifetimeRunNumber = 0,
    this.runsSinceLastInterstitial = 0,
    this.replayFingerprint = '',
  });

  final int score;
  final double distanceMeters;
  final int coinsCollected;
  final int nearMisses;
  final bool isNewHighScore;
  final Biome finalBiome;
  final bool wasRevived;
  final bool doubleCoinsApplied;
  final double runDurationSeconds;
  final String crashCause;
  final int maxCombo;
  final int powerUpsUsed;

  /// Projected counters for this completed run. They are captured before the
  /// asynchronous Hive write so ad eligibility never races persistence.
  final int lifetimeRunNumber;
  final int runsSinceLastInterstitial;

  /// Bounded deterministic layout signature for replay/soak verification.
  final String replayFingerprint;

  int get effectiveCoins =>
      doubleCoinsApplied ? coinsCollected * 2 : coinsCollected;

  RunResult copyWith({
    int? score,
    double? distanceMeters,
    int? coinsCollected,
    int? nearMisses,
    bool? isNewHighScore,
    Biome? finalBiome,
    bool? wasRevived,
    bool? doubleCoinsApplied,
    double? runDurationSeconds,
    String? crashCause,
    int? maxCombo,
    int? powerUpsUsed,
    int? lifetimeRunNumber,
    int? runsSinceLastInterstitial,
    String? replayFingerprint,
  }) {
    return RunResult(
      score: score ?? this.score,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      coinsCollected: coinsCollected ?? this.coinsCollected,
      nearMisses: nearMisses ?? this.nearMisses,
      isNewHighScore: isNewHighScore ?? this.isNewHighScore,
      finalBiome: finalBiome ?? this.finalBiome,
      wasRevived: wasRevived ?? this.wasRevived,
      doubleCoinsApplied: doubleCoinsApplied ?? this.doubleCoinsApplied,
      runDurationSeconds: runDurationSeconds ?? this.runDurationSeconds,
      crashCause: crashCause ?? this.crashCause,
      maxCombo: maxCombo ?? this.maxCombo,
      powerUpsUsed: powerUpsUsed ?? this.powerUpsUsed,
      lifetimeRunNumber: lifetimeRunNumber ?? this.lifetimeRunNumber,
      runsSinceLastInterstitial:
          runsSinceLastInterstitial ?? this.runsSinceLastInterstitial,
      replayFingerprint: replayFingerprint ?? this.replayFingerprint,
    );
  }
}
