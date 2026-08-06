import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/game_enums.dart';
import '../models/run_result.dart';

/// Snapshot of run progress at the moment of a crash — used to restore
/// after a rewarded-ad revive (new FlameGame instance).
class RunSnapshot {
  const RunSnapshot({
    required this.score,
    required this.distanceMeters,
    required this.coinsThisRun,
    required this.nearMissesThisRun,
    required this.comboCount,
    required this.comboMultiplier,
    required this.currentBiome,
    required this.scrollSpeed,
  });

  final int score;
  final double distanceMeters;
  final int coinsThisRun;
  final int nearMissesThisRun;
  final int comboCount;
  final double comboMultiplier;
  final Biome currentBiome;
  final double scrollSpeed;
}

/// Ephemeral state for an active or just-completed game session.
/// Lives in Riverpod so the HUD overlay and game-over screen can react to it.
/// Reset on each new run — not persisted to Hive.
class GameSessionState {
  const GameSessionState({
    this.phase = GamePhase.idle,
    this.score = 0,
    this.distanceMeters = 0,
    this.coinsThisRun = 0,
    this.nearMissesThisRun = 0,
    this.comboCount = 0,
    this.comboMultiplier = 1.0,
    this.currentBiome = Biome.backyard,
    this.activePowerUps = const {},
    this.shieldActive = false,
    this.lastRunResult,
    this.canRevive = true,
    this.crashSnapshot,
  });

  final GamePhase phase;
  final int score;
  final double distanceMeters;
  final int coinsThisRun;
  final int nearMissesThisRun;
  final int comboCount;
  final double comboMultiplier;
  final Biome currentBiome;
  final Set<PowerUpType> activePowerUps;
  final bool shieldActive;
  final RunResult? lastRunResult;
  final bool canRevive;
  final RunSnapshot? crashSnapshot;

  GameSessionState copyWith({
    GamePhase? phase,
    int? score,
    double? distanceMeters,
    int? coinsThisRun,
    int? nearMissesThisRun,
    int? comboCount,
    double? comboMultiplier,
    Biome? currentBiome,
    Set<PowerUpType>? activePowerUps,
    bool? shieldActive,
    RunResult? lastRunResult,
    bool? canRevive,
    RunSnapshot? crashSnapshot,
    bool clearCrashSnapshot = false,
    bool clearLastRunResult = false,
  }) {
    return GameSessionState(
      phase: phase ?? this.phase,
      score: score ?? this.score,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      coinsThisRun: coinsThisRun ?? this.coinsThisRun,
      nearMissesThisRun: nearMissesThisRun ?? this.nearMissesThisRun,
      comboCount: comboCount ?? this.comboCount,
      comboMultiplier: comboMultiplier ?? this.comboMultiplier,
      currentBiome: currentBiome ?? this.currentBiome,
      activePowerUps: activePowerUps ?? this.activePowerUps,
      shieldActive: shieldActive ?? this.shieldActive,
      lastRunResult:
          clearLastRunResult ? null : (lastRunResult ?? this.lastRunResult),
      canRevive: canRevive ?? this.canRevive,
      crashSnapshot: clearCrashSnapshot
          ? null
          : (crashSnapshot ?? this.crashSnapshot),
    );
  }
}

class GameSessionNotifier extends Notifier<GameSessionState> {
  @override
  GameSessionState build() => const GameSessionState();

  void startRun() {
    state = const GameSessionState(phase: GamePhase.playing, canRevive: true);
  }

  /// Restore a run after revive — keeps progress, marks revive used.
  void restoreFromSnapshot(RunSnapshot snap) {
    state = GameSessionState(
      phase: GamePhase.playing,
      score: snap.score,
      distanceMeters: snap.distanceMeters,
      coinsThisRun: snap.coinsThisRun,
      nearMissesThisRun: snap.nearMissesThisRun,
      comboCount: snap.comboCount,
      comboMultiplier: snap.comboMultiplier,
      currentBiome: snap.currentBiome,
      canRevive: false,
      shieldActive: true,
      activePowerUps: {PowerUpType.shield},
    );
  }

  void updateScore(int score) {
    state = state.copyWith(score: score);
  }

  void updateDistance(double meters) {
    state = state.copyWith(distanceMeters: meters);
  }

  void updateCoins(int count) {
    state = state.copyWith(coinsThisRun: count);
  }

  void updateCombo(int count, double multiplier) {
    state = state.copyWith(comboCount: count, comboMultiplier: multiplier);
  }

  void addNearMiss() {
    state = state.copyWith(nearMissesThisRun: state.nearMissesThisRun + 1);
  }

  void updateBiome(Biome biome) {
    state = state.copyWith(currentBiome: biome);
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
    );
  }

  void consumeShield() {
    final updated = Set<PowerUpType>.from(state.activePowerUps)
      ..remove(PowerUpType.shield);
    state = state.copyWith(activePowerUps: updated, shieldActive: false);
  }

  void saveCrashSnapshot(RunSnapshot snapshot) {
    state = state.copyWith(crashSnapshot: snapshot);
  }

  void triggerGameOver(RunResult result) {
    state = state.copyWith(
      phase: GamePhase.gameOver,
      lastRunResult: result,
    );
  }

  void useRevive() {
    state = state.copyWith(
      phase: GamePhase.playing,
      canRevive: false,
      shieldActive: true,
      activePowerUps: {PowerUpType.shield},
      clearLastRunResult: true,
    );
  }

  void pause() => state = state.copyWith(phase: GamePhase.paused);
  void resume() => state = state.copyWith(phase: GamePhase.playing);
}

final gameSessionProvider =
    NotifierProvider<GameSessionNotifier, GameSessionState>(
  GameSessionNotifier.new,
);
