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
  });

  final int score;
  final double distanceMeters;
  final int coinsCollected;
  final int nearMisses;
  final bool isNewHighScore;
  final Biome finalBiome;
  final bool wasRevived;
  final bool doubleCoinsApplied;

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
    );
  }
}
