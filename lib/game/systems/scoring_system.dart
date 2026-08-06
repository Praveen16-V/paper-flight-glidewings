import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
import '../components/effects/coin_feedback.dart';
import '../paper_flight_game.dart';

/// Owns all score calculation and pushes updates to [gameSessionProvider].
///
/// Score formula (per GDD §6, extended for risk-reward design):
///   distance_score   = distanceMeters × scorePerMeter
///   coin_score       = Σ coin awards (combo multiplier at time of pickup)
///   near_miss_bonus  = Σ tiered near-miss awards (25 / 50 / 100 by tier)
///   streak_bonus     = Σ clean-flight glide & thermal-surf payouts
///   total            = sum of all above
///
/// Combo model — Combo Decay Gauge (replaces instant reset):
///   The combo is a fractional gauge measured in notches (0..comboMax).
///   Every coin adds exactly one notch. Whenever no coins are collected the
///   gauge continuously bleeds dry over [GameConfig.comboDrainDuration]
///   seconds for a full bank — the displayed count (ceil) drops one notch at
///   a time and the multiplier follows. A shield-absorbed obstacle hit keeps
///   [GameConfig.comboHitRetentionFraction] of the gauge instead of zeroing
///   it, so neither brief coin gaps nor a single mistake ever face the old
///   binary wipe.
class ScoringSystem extends Component {
  ScoringSystem({required this.game});

  final PaperFlightGame game;

  int _score = 0;
  int _coinsThisRun = 0;
  int _nearMissesThisRun = 0;
  int _nearMissScoreAccumulated = 0;
  int _coinScoreAccumulated = 0;
  int _streakScoreAccumulated = 0;

  /// Fractional combo gauge in notch units (0..comboMax). Coins add whole
  /// notches; idle time bleeds notches at a constant rate.
  double _comboGauge = 0;

  int get score => _score;
  int get coinsThisRun => _coinsThisRun;
  int get nearMissesThisRun => _nearMissesThisRun;

  /// Displayed combo notch count — drops one notch at a time as the gauge
  /// bleeds, never all at once.
  int get comboCount => _comboGauge.ceil();

  double get comboMultiplier =>
      1.0 + (comboCount * GameConfig.comboMultiplierStep);

  /// Gauge as a 0..1 fraction of a full bank — drives the HUD drain bar.
  double get comboGaugeFraction =>
      (_comboGauge / GameConfig.comboMax).clamp(0.0, 1.0).toDouble();

  // How frequently (in seconds) we push score to provider.
  static const double _pushInterval = 0.1;
  double _pushTimer = 0;

  /// Notches bled per second so that a full bank drains in exactly
  /// [GameConfig.comboDrainDuration] seconds.
  static double get _drainRate =>
      GameConfig.comboMax / GameConfig.comboDrainDuration;

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;

    // Combo decay gauge: continuously drains while no coins are feeding it.
    if (_comboGauge > 0) {
      _comboGauge = (_comboGauge - _drainRate * dt)
          .clamp(0.0, GameConfig.comboMax.toDouble())
          .toDouble();
    }

    // Distance-based score accumulates continuously.
    final distScore = (game.distanceMeters * GameConfig.scorePerMeter).toInt();
    _score = distScore +
        _coinScoreAccumulated +
        _nearMissScoreAccumulated +
        _streakScoreAccumulated;

    _pushTimer += dt;
    if (_pushTimer >= _pushInterval) {
      _pushTimer = 0;
      final notifier = game.ref.read(gameSessionProvider.notifier);
      notifier.updateScore(_score);
      notifier.updateCoins(_coinsThisRun);
      notifier.updateCombo(comboCount, comboMultiplier, comboGaugeFraction);
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call when a coin is collected. Returns the points awarded.
  int onCoinCollected() {
    // Each coin restores exactly one notch of the decaying gauge.
    _comboGauge = (_comboGauge + 1.0)
        .clamp(0.0, GameConfig.comboMax.toDouble())
        .toDouble();
    _coinsThisRun++;
    var points = (comboMultiplier * 10).toInt();
    // Coin Rush: every coin is worth 2× for the duration of the power-up.
    final session = game.ref.read(gameSessionProvider);
    if (session.activePowerUps.contains(PowerUpType.coinRush)) {
      points = (points * GameConfig.coinRushValueMultiplier).toInt();
    }
    _coinScoreAccumulated += points;
    return points;
  }

  /// Call when the plane hits an obstacle and the hit is absorbed by the
  /// shield. Instead of resetting the combo to zero, the stunt costs half of
  /// the remaining gauge — painful at ×3.0, survivable at ×1.2.
  void onObstacleHit() {
    _comboGauge *= GameConfig.comboHitRetentionFraction;
  }

  /// Call when a near-miss pass is confirmed (award fires once the two
  /// bodies separate, using the tightest tier reached at closest approach).
  int onNearMiss({
    Vector2? position,
    NearMissTier tier = NearMissTier.closeShave,
  }) {
    _nearMissesThisRun++;
    game.ref.read(gameSessionProvider.notifier).addNearMiss();
    final points = tier.points;
    _nearMissScoreAccumulated += points;
    final spawnPos = position ?? game.plane.position.clone();
    spawnNearMissFeedback(game, spawnPos, tier, points);
    // Death Defying earns the full drama: micro hit-stop + camera pulse.
    if (tier == NearMissTier.deathDefying) {
      game.triggerDeathDefyingSlowMo();
    }
    return points;
  }

  /// Call by streak trackers (smooth glide, thermal surf) to bank flat
  /// bonus points. Streak payouts intentionally ignore the coin combo
  /// multiplier — they escalate on their own schedule.
  void awardStreakBonus(int points) {
    _streakScoreAccumulated += points;
  }

  void reset() {
    _score = 0;
    _coinsThisRun = 0;
    _nearMissesThisRun = 0;
    _nearMissScoreAccumulated = 0;
    _coinScoreAccumulated = 0;
    _streakScoreAccumulated = 0;
    _comboGauge = 0;
    _pushTimer = 0;
  }
}
