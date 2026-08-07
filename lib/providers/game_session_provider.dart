import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/game_enums.dart';
import '../models/run_result.dart';

/// Outcome snapshot for a completed Precision Trial — pushed to the provider
/// so the GameScreen can route to the trial results screen.
class TrialOutcome {
  const TrialOutcome({
    required this.trialId,
    required this.completed,
    required this.timedOut,
    required this.stars,
    required this.timeUsedSeconds,
    required this.coinsCollected,
    required this.totalCoins,
    required this.isNewBestStars,
  });

  final int trialId;
  final bool completed;

  /// True when the run failed because the clock hit zero (vs a crash).
  final bool timedOut;

  /// 0–3 stars. 0 when the trial was failed or timed out.
  final int stars;
  final double timeUsedSeconds;
  final int coinsCollected;
  final int totalCoins;
  final bool isNewBestStars;
}

/// Ephemeral state for an active or just-completed game session.
/// Lives in Riverpod so the HUD overlay and game-over screen can react to it.
/// Reset on each new run — not persisted to Hive.
class GameSessionState {
  const GameSessionState({
    this.phase = GamePhase.idle,
    this.mode = GameMode.classic,
    this.trialId,
    this.score = 0,
    this.distanceMeters = 0,
    this.coinsThisRun = 0,
    this.nearMissesThisRun = 0,
    this.comboCount = 0,
    this.comboMultiplier = 1.0,
    this.comboGauge = 0.0,
    this.currentBiome = Biome.city,
    this.activePowerUps = const {},
    this.shieldActive = false,
    this.powerUpRemaining = const {},
    this.lastRunResult,
    this.canRevive = true, // one free revive attempt per run
    this.runTimeSeconds = 0,
    this.trialTimeLeft,
    this.trialOutcome,
  });

  final GamePhase phase;
  final GameMode mode;

  /// Active trial id — non-null only in [GameMode.trial].
  final int? trialId;
  final int score;
  final double distanceMeters;
  final int coinsThisRun;
  final int nearMissesThisRun;
  final int comboCount;
  final double comboMultiplier;

  /// Combo decay gauge, 0.0–1.0 (fraction of a full combo bank). The gauge
  /// bleeds down over the configured drain duration whenever no coins are
  /// being collected; each coin restores exactly one notch.
  final double comboGauge;
  final Biome currentBiome;
  final Set<PowerUpType> activePowerUps;
  final bool shieldActive;
  final Map<PowerUpType, double> powerUpRemaining;
  final RunResult? lastRunResult;
  final bool canRevive;

  /// Wall-clock seconds since this run started (Zen + trial HUD).
  final double runTimeSeconds;

  /// Remaining seconds on the trial clock (null when the trial has no limit).
  final double? trialTimeLeft;

  /// Set when a Precision Trial completes or fails.
  final TrialOutcome? trialOutcome;

  GameSessionState copyWith({
    GamePhase? phase,
    GameMode? mode,
    int? trialId,
    int? score,
    double? distanceMeters,
    int? coinsThisRun,
    int? nearMissesThisRun,
    int? comboCount,
    double? comboMultiplier,
    double? comboGauge,
    Biome? currentBiome,
    Set<PowerUpType>? activePowerUps,
    bool? shieldActive,
    Map<PowerUpType, double>? powerUpRemaining,
    RunResult? lastRunResult,
    bool? canRevive,
    double? runTimeSeconds,
    double? trialTimeLeft,
    TrialOutcome? trialOutcome,
  }) {
    return GameSessionState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      trialId: trialId ?? this.trialId,
      score: score ?? this.score,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      coinsThisRun: coinsThisRun ?? this.coinsThisRun,
      nearMissesThisRun: nearMissesThisRun ?? this.nearMissesThisRun,
      comboCount: comboCount ?? this.comboCount,
      comboMultiplier: comboMultiplier ?? this.comboMultiplier,
      comboGauge: comboGauge ?? this.comboGauge,
      currentBiome: currentBiome ?? this.currentBiome,
      activePowerUps: activePowerUps ?? this.activePowerUps,
      shieldActive: shieldActive ?? this.shieldActive,
      powerUpRemaining: powerUpRemaining ?? this.powerUpRemaining,
      lastRunResult: lastRunResult ?? this.lastRunResult,
      canRevive: canRevive ?? this.canRevive,
      runTimeSeconds: runTimeSeconds ?? this.runTimeSeconds,
      trialTimeLeft: trialTimeLeft ?? this.trialTimeLeft,
      trialOutcome: trialOutcome ?? this.trialOutcome,
    );
  }
}

class GameSessionNotifier extends Notifier<GameSessionState> {
  @override
  GameSessionState build() => const GameSessionState();

  void startRun({GameMode mode = GameMode.classic, int? trialId}) {
    state = GameSessionState(
      phase: GamePhase.playing,
      mode: mode,
      trialId: trialId,
      canRevive: true,
    );
  }

  void updateScore(int score) {
    state = state.copyWith(score: score);
  }

  void updateDistance(double meters) {
    state = state.copyWith(distanceMeters: meters);
  }

  void updateRunTime(double seconds) {
    state = state.copyWith(runTimeSeconds: seconds);
  }

  void updateTrialTime(double seconds) {
    state = state.copyWith(trialTimeLeft: seconds);
  }

  void updateCoins(int count) {
    state = state.copyWith(coinsThisRun: count);
  }

  void updateCombo(int count, double multiplier, [double? gauge]) {
    state = state.copyWith(
      comboCount: count,
      comboMultiplier: multiplier,
      comboGauge: gauge ?? state.comboGauge,
    );
  }

  void addNearMiss() {
    state = state.copyWith(nearMissesThisRun: state.nearMissesThisRun + 1);
  }

  void updateBiome(Biome biome) {
    state = state.copyWith(currentBiome: biome);
  }

  void setPowerUpTimer(PowerUpType type, double seconds) {
    final timers = Map<PowerUpType, double>.from(state.powerUpRemaining)..[type] = seconds;
    state = state.copyWith(powerUpRemaining: timers);
  }

  void activatePowerUp(PowerUpType type) {
    final updated = Set<PowerUpType>.from(state.activePowerUps)..add(type);
    state = state.copyWith(
      activePowerUps: updated,
      shieldActive: type == PowerUpType.shield ? true : state.shieldActive,
    );
  }

  void deactivatePowerUp(PowerUpType type) {
    final updated = Set<PowerUpType>.from(state.activePowerUps)..remove(type);
    state = state.copyWith(
      activePowerUps: updated,
      shieldActive: type == PowerUpType.shield ? false : state.shieldActive,
      powerUpRemaining: Map<PowerUpType, double>.from(state.powerUpRemaining)..remove(type),
    );
  }

  void consumeShield() {
    final updated = Set<PowerUpType>.from(state.activePowerUps)
      ..remove(PowerUpType.shield);
    state = state.copyWith(activePowerUps: updated, shieldActive: false);
  }

  void triggerGameOver(RunResult result) {
    state = state.copyWith(
      phase: GamePhase.gameOver,
      lastRunResult: result,
    );
  }

  /// Precision Trial finished — phase → gameOver with the outcome attached.
  void completeTrial(TrialOutcome outcome) {
    state = state.copyWith(
      phase: GamePhase.gameOver,
      trialOutcome: outcome,
      lastRunResult: null,
    );
  }

  /// Zen Flight ended from the pause menu — phase → gameOver, no run result.
  void endZen() {
    state = state.copyWith(
      phase: GamePhase.gameOver,
      lastRunResult: null,
      trialOutcome: null,
    );
  }

  void useRevive() {
    state = state.copyWith(
      phase: GamePhase.playing,
      canRevive: false,
      shieldActive: false,
    );
  }

  void pause() => state = state.copyWith(phase: GamePhase.paused);
  void resume() => state = state.copyWith(phase: GamePhase.playing);
}

final gameSessionProvider =
    NotifierProvider<GameSessionNotifier, GameSessionState>(
  GameSessionNotifier.new,
);
