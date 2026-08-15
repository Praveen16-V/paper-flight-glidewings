import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/game_config.dart';
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

/// A power-up pickup the player should be told about.
///
/// Carries an [id] because the same power-up can legitimately be collected
/// twice in a row: the id changes on every pickup, which is what lets the HUD
/// replay its entry animation instead of treating the second grab as a
/// no-change rebuild.
class PickupAnnouncement {
  const PickupAnnouncement({
    required this.id,
    required this.type,
    this.corrupted,
  });

  final int id;
  final PowerUpType type;

  /// Set when the pickup was a corrupted bargain, so the banner can warn
  /// rather than celebrate.
  final CorruptedPowerUpType? corrupted;

  bool get isCorrupted => corrupted != null;

  /// Headline text: the name of what was just collected.
  String get title =>
      (corrupted?.displayName ?? type.displayName).toUpperCase();

  /// Supporting line explaining what it does.
  String get subtitle => corrupted?.warning ?? type.pickupSummary;
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
    this.activeCorruptedPowerUps = const {},
    this.corruptedPowerUpRemaining = const {},
    this.shieldActive = false,
    this.powerUpRemaining = const {},
    this.powerUpCooldowns = const {},
    this.pickupAnnouncement,
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
  /// Power-ups running right now. A pickup activates on contact, so this is
  /// simply "what the player is currently benefiting from" — there is no
  /// separate bank of stored charges.
  final Set<PowerUpType> activePowerUps;

  /// Immediate risk/reward effects from corrupted world pickups.
  final Set<CorruptedPowerUpType> activeCorruptedPowerUps;
  final Map<CorruptedPowerUpType, double> corruptedPowerUpRemaining;

  /// Derived stacked effects for HUD and gameplay systems. Keeping it derived
  /// prevents stale combo state when any underlying timer expires.
  Set<PowerUpCombo> get activePowerUpCombos =>
      powerUpCombosFor(activePowerUps);

  final bool shieldActive;
  final Map<PowerUpType, double> powerUpRemaining;

  /// Seconds left before each type can take effect again. A type present here
  /// is recharging; absent means ready.
  final Map<PowerUpType, double> powerUpCooldowns;

  /// True when [type] cannot be activated yet because it is still recharging.
  bool isRecharging(PowerUpType type) =>
      (powerUpCooldowns[type] ?? 0) > 0;

  /// The most recent power-up pickup, surfaced so the HUD can announce it to
  /// the player. Cleared once the banner has had its moment on screen.
  final PickupAnnouncement? pickupAnnouncement;

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
    Set<CorruptedPowerUpType>? activeCorruptedPowerUps,
    Map<CorruptedPowerUpType, double>? corruptedPowerUpRemaining,
    bool? shieldActive,
    Map<PowerUpType, double>? powerUpRemaining,
    Map<PowerUpType, double>? powerUpCooldowns,
    PickupAnnouncement? pickupAnnouncement,
    bool clearPickupAnnouncement = false,
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
      activeCorruptedPowerUps:
          activeCorruptedPowerUps ?? this.activeCorruptedPowerUps,
      corruptedPowerUpRemaining:
          corruptedPowerUpRemaining ?? this.corruptedPowerUpRemaining,
      shieldActive: shieldActive ?? this.shieldActive,
      powerUpRemaining: powerUpRemaining ?? this.powerUpRemaining,
      powerUpCooldowns: powerUpCooldowns ?? this.powerUpCooldowns,
      pickupAnnouncement: clearPickupAnnouncement
          ? null
          : (pickupAnnouncement ?? this.pickupAnnouncement),
      lastRunResult: lastRunResult ?? this.lastRunResult,
      canRevive: canRevive ?? this.canRevive,
      runTimeSeconds: runTimeSeconds ?? this.runTimeSeconds,
      trialTimeLeft: trialTimeLeft ?? this.trialTimeLeft,
      trialOutcome: trialOutcome ?? this.trialOutcome,
    );
  }
}

class GameSessionNotifier extends Notifier<GameSessionState> {
  /// Monotonic id source for pickup announcements.
  int _announcementCounter = 0;

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

  /// Batches the two continuously changing HUD values into one provider
  /// notification, avoiding back-to-back rebuilds every telemetry tick.
  void updateFlightMetrics({
    required double distanceMeters,
    required double runTimeSeconds,
  }) {
    state = state.copyWith(
      distanceMeters: distanceMeters,
      runTimeSeconds: runTimeSeconds,
    );
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

  /// Advances every live power-up clock by [elapsed] seconds and drops any
  /// effect whose timer reached zero. This is the single expiry authority:
  /// power-ups end because their timer ran out, never because some unrelated
  /// wall-clock callback happened to fire.
  ///
  /// Also drains per-type recharge timers, so a power-up that has ended
  /// cannot be re-activated until its cooldown clears.
  ///
  /// Returns the set of types that expired on this tick so the game loop can
  /// unwind their side effects (timescale, shield charges).
  Set<PowerUpType> tickPowerUpTimers(double elapsed) {
    if (elapsed <= 0) return const {};
    if (state.activePowerUps.isEmpty &&
        state.activeCorruptedPowerUps.isEmpty &&
        state.powerUpCooldowns.isEmpty) {
      return const {};
    }

    // Drain recharge timers first: a type whose cooldown ends this tick is
    // ready again immediately, rather than a frame late.
    var cooldowns = state.powerUpCooldowns;
    if (cooldowns.isNotEmpty) {
      final next = <PowerUpType, double>{};
      for (final entry in cooldowns.entries) {
        final left = entry.value - elapsed;
        if (left > 0) next[entry.key] = left;
      }
      cooldowns = next;
    }

    final timers = Map<PowerUpType, double>.from(state.powerUpRemaining);
    final expired = <PowerUpType>{};
    for (final type in state.activePowerUps) {
      final remaining = timers[type];
      if (remaining == null) continue;
      final next = remaining - elapsed;
      if (next <= 0) {
        expired.add(type);
        timers.remove(type);
      } else {
        timers[type] = next;
      }
    }

    final corruptedRemaining =
        Map<CorruptedPowerUpType, double>.from(state.corruptedPowerUpRemaining);
    final corruptedExpired = <CorruptedPowerUpType>{};
    for (final type in state.activeCorruptedPowerUps) {
      final remaining = corruptedRemaining[type];
      if (remaining == null) continue;
      final next = remaining - elapsed;
      if (next <= 0) {
        corruptedExpired.add(type);
        corruptedRemaining.remove(type);
      } else {
        corruptedRemaining[type] = next;
      }
    }

    if (expired.isEmpty && corruptedExpired.isEmpty) {
      state = state.copyWith(
        powerUpRemaining: timers,
        corruptedPowerUpRemaining: corruptedRemaining,
        powerUpCooldowns: cooldowns,
      );
      return const {};
    }

    // An effect that just ended starts recharging.
    final withCooldowns = Map<PowerUpType, double>.from(cooldowns);
    for (final type in expired) {
      withCooldowns[type] = GameConfig.powerUpRechargeFor(type);
    }

    final active = Set<PowerUpType>.from(state.activePowerUps)
      ..removeAll(expired);
    final activeCorrupted =
        Set<CorruptedPowerUpType>.from(state.activeCorruptedPowerUps)
          ..removeAll(corruptedExpired);

    state = state.copyWith(
      activePowerUps: active,
      activeCorruptedPowerUps: activeCorrupted,
      powerUpRemaining: timers,
      corruptedPowerUpRemaining: corruptedRemaining,
      powerUpCooldowns: withCooldowns,
      shieldActive:
          expired.contains(PowerUpType.shield) ? false : state.shieldActive,
    );
    return expired;
  }

  /// Announces a pickup so the HUD can tell the player what they just got.
  /// Each call gets a fresh id so repeat pickups of the same type still
  /// re-trigger the banner.
  void announcePickup(PowerUpType type, {CorruptedPowerUpType? corrupted}) {
    state = state.copyWith(
      pickupAnnouncement: PickupAnnouncement(
        id: ++_announcementCounter,
        type: type,
        corrupted: corrupted,
      ),
    );
  }

  /// Retires the current banner once it has finished its time on screen.
  void clearPickupAnnouncement([int? id]) {
    final current = state.pickupAnnouncement;
    if (current == null) return;
    // Ignore a stale dismissal from a banner that has already been replaced
    // by a newer pickup.
    if (id != null && current.id != id) return;
    state = state.copyWith(clearPickupAnnouncement: true);
  }

  /// Activates a power-up immediately. Collecting a type that is already
  /// running simply refreshes it (the caller republishes the timer), so
  /// effects never stack into compounding advantages.
  void activatePowerUp(PowerUpType type) {
    final updated = Set<PowerUpType>.from(state.activePowerUps)..add(type);
    state = state.copyWith(
      activePowerUps: updated,
      shieldActive: type == PowerUpType.shield ? true : state.shieldActive,
    );
  }

  void activateCorruptedPowerUp(CorruptedPowerUpType type, double duration) {
    final active = Set<CorruptedPowerUpType>.from(state.activeCorruptedPowerUps)
      ..add(type);
    final remaining =
        Map<CorruptedPowerUpType, double>.from(state.corruptedPowerUpRemaining)
          ..[type] = duration;
    state = state.copyWith(
      activeCorruptedPowerUps: active,
      corruptedPowerUpRemaining: remaining,
    );
  }

  void deactivateCorruptedPowerUp(CorruptedPowerUpType type) {
    final active = Set<CorruptedPowerUpType>.from(state.activeCorruptedPowerUps)
      ..remove(type);
    final remaining =
        Map<CorruptedPowerUpType, double>.from(state.corruptedPowerUpRemaining)
          ..remove(type);
    state = state.copyWith(
      activeCorruptedPowerUps: active,
      corruptedPowerUpRemaining: remaining,
    );
  }

  void setCorruptedPowerUpTimer(CorruptedPowerUpType type, double seconds) {
    final remaining =
        Map<CorruptedPowerUpType, double>.from(state.corruptedPowerUpRemaining)
          ..[type] = seconds;
    state = state.copyWith(corruptedPowerUpRemaining: remaining);
  }

  void deactivatePowerUp(PowerUpType type) {
    final updated = Set<PowerUpType>.from(state.activePowerUps)..remove(type);
    state = state.copyWith(
      activePowerUps: updated,
      shieldActive: type == PowerUpType.shield ? false : state.shieldActive,
      powerUpRemaining: Map<PowerUpType, double>.from(state.powerUpRemaining)..remove(type),
    );
  }

  /// The shield's last charge was spent on an impact. It ends early — and its
  /// countdown is cleared with it so the HUD never shows a ring for an effect
  /// that is already gone.
  void consumeShield() {
    final updated = Set<PowerUpType>.from(state.activePowerUps)
      ..remove(PowerUpType.shield);
    state = state.copyWith(
      activePowerUps: updated,
      shieldActive: false,
      powerUpRemaining: Map<PowerUpType, double>.from(state.powerUpRemaining)
        ..remove(PowerUpType.shield),
      // Spending the shield on an impact ends it, so it recharges just as if
      // its timer had run out.
      powerUpCooldowns: Map<PowerUpType, double>.from(state.powerUpCooldowns)
        ..[PowerUpType.shield] =
            GameConfig.powerUpRechargeFor(PowerUpType.shield),
    );
  }

  /// Ends every live effect at once.
  ///
  /// The loop's timer tick only advances while the run is playing, so anything
  /// still running when a run finishes would otherwise stay frozen on the HUD
  /// with a half-drained ring. A run that is over has no active power-ups.
  void clearAllPowerUps() {
    state = state.copyWith(
      activePowerUps: const {},
      activeCorruptedPowerUps: const {},
      powerUpRemaining: const {},
      corruptedPowerUpRemaining: const {},
      powerUpCooldowns: const {},
      shieldActive: false,
      clearPickupAnnouncement: true,
    );
  }

  void triggerGameOver(RunResult result) {
    state = state.copyWith(
      phase: GamePhase.gameOver,
      lastRunResult: result,
      // A finished run shows no live effects.
      activePowerUps: const {},
      activeCorruptedPowerUps: const {},
      powerUpRemaining: const {},
      corruptedPowerUpRemaining: const {},
      powerUpCooldowns: const {},
      shieldActive: false,
      clearPickupAnnouncement: true,
    );
  }

  /// Precision Trial finished — phase → gameOver with the outcome attached.
  void completeTrial(TrialOutcome outcome) {
    state = state.copyWith(
      phase: GamePhase.gameOver,
      trialOutcome: outcome,
      lastRunResult: null,
      activePowerUps: const {},
      activeCorruptedPowerUps: const {},
      powerUpRemaining: const {},
      corruptedPowerUpRemaining: const {},
      powerUpCooldowns: const {},
      shieldActive: false,
      clearPickupAnnouncement: true,
    );
  }

  /// Zen Flight ended from the pause menu — phase → gameOver, no run result.
  void endZen() {
    state = state.copyWith(
      phase: GamePhase.gameOver,
      lastRunResult: null,
      trialOutcome: null,
      activePowerUps: const {},
      activeCorruptedPowerUps: const {},
      powerUpRemaining: const {},
      corruptedPowerUpRemaining: const {},
      powerUpCooldowns: const {},
      shieldActive: false,
      clearPickupAnnouncement: true,
    );
  }

  /// Reviving resumes the run with a clean slate: whatever was running when
  /// the plane went down died with it, so no stale ring survives the revive.
  void useRevive() {
    state = state.copyWith(
      phase: GamePhase.playing,
      canRevive: false,
      activePowerUps: const {},
      activeCorruptedPowerUps: const {},
      powerUpRemaining: const {},
      corruptedPowerUpRemaining: const {},
      powerUpCooldowns: const {},
      shieldActive: false,
      clearPickupAnnouncement: true,
    );
  }

  void pause() => state = state.copyWith(phase: GamePhase.paused);
  void resume() => state = state.copyWith(phase: GamePhase.playing);
}

final gameSessionProvider =
    NotifierProvider<GameSessionNotifier, GameSessionState>(
  GameSessionNotifier.new,
);
