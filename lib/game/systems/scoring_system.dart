import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
import '../components/effects/coin_feedback.dart';
import '../events/gameplay_event_bus.dart';
import '../paper_flight_game.dart';

/// Owns all score calculation and pushes updates to [gameSessionProvider].
///
/// Score formula (per GDD §6, extended for risk-reward design):
///   distance_score   = distanceMeters × scorePerMeter × planeBonus
///   coin_score       = Σ coin awards (combo multiplier at time of pickup)
///   near_miss_bonus  = Σ tiered near-miss awards (25 / 50 / 100 by tier × planeBonus)
///   streak_bonus     = Σ clean-flight glide & thermal-surf payouts
///   total            = sum of all above
///
/// Plane bonuses (Task 7):
///   Dart  +15% distance score
///   Stunt +50% near-miss score
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
    // Albatross perk: 50%..75% slower combo decay while in glide!
    if (_comboGauge > 0) {
      var effectiveDrain = _drainRate;
      try {
        if (game.plane.planeType == PlaneType.albatross) {
          final decayMult = game.plane.planeLevel >= 3 ? 0.25 : (game.plane.planeLevel == 2 ? 0.40 : 0.50);
          effectiveDrain *= decayMult;
        }
      } catch (_) {}

      _comboGauge = (_comboGauge - effectiveDrain * dt)
          .clamp(0.0, GameConfig.comboMax.toDouble())
          .toDouble();
    }

    // Distance-based score accumulates continuously — Dart gets distance bonus (+15%..+25%).
    var distScore = (game.distanceMeters * GameConfig.scorePerMeter).toInt();
    try {
      if (game.powerUpState.doubleScoreActive) {
        distScore *= 2; // Double Score power-up: 2x distance meters score!
      }
      if (game.plane.planeType == PlaneType.dart) {
        final dartBonus = game.plane.planeLevel >= 3
            ? 1.25
            : (game.plane.planeLevel == 2 ? 1.20 : GameConfig.dartDistanceBonusMultiplier);
        distScore = (distScore * dartBonus).toInt();
      } else if (game.plane.planeType == PlaneType.interceptor && game.plane.planeLevel >= 3) {
        distScore = (distScore * 1.20).toInt();
      } else if (game.plane.planeType == PlaneType.rocket) {
        final rBonus = game.plane.planeLevel >= 3 ? 1.25 : (game.plane.planeLevel == 2 ? 1.15 : 1.0);
        distScore = (distScore * rBonus).toInt();
      }
    } catch (_) {}

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
      final empowered = session.activeEmpoweredPowerUps
          .contains(PowerUpType.coinRush);
      final coinMultiplier =
          session.activePowerUpCombos.contains(PowerUpCombo.goldVortex)
              ? (empowered
                  ? GameConfig.empoweredGoldVortexCoinValueMultiplier
                  : GameConfig.goldVortexCoinValueMultiplier)
              : (empowered
                  ? GameConfig.empoweredCoinRushValueMultiplier
                  : GameConfig.coinRushValueMultiplier);
      points = (points * coinMultiplier).toInt();
    }
    // Zen/Daily wingmen reward disciplined proximity with richer coin value.
    // Classic has no active wingmen, so this remains exactly 1.0 there.
    final formationMultiplier = game.wingmanSystem.coinScoreMultiplier;
    if (formationMultiplier > 1.0) {
      points = (points * formationMultiplier).round();
    }
    _coinScoreAccumulated += points;
    // Skin reactions receive score-confirmed coin events, including 5x stacks
    // and elite bonus coins that do not originate from a CoinComponent.
    game.plane.onGameEvent(SkinGameEvent.coinCollected);
    // Juice: coin tap haptic + ascending combo-chime melody (Task 6).
    game.gameFeelSystem.onCoinCollected(comboCount);
    return points;
  }

  /// Restores [notches] to the decaying combo gauge.
  void awardComboNotches(double notches) {
    _comboGauge = (_comboGauge + notches)
        .clamp(0.0, GameConfig.comboMax.toDouble())
        .toDouble();
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
    game.gameplayEvents.emit(NearMissGameplayEvent(tier));
    var points = tier.points;
    // Stunt Fold: +50%..+100% near-miss score
    try {
      if (game.plane.planeType == PlaneType.stuntFold) {
        final mult = game.plane.planeLevel >= 3
            ? 2.0
            : (game.plane.planeLevel == 2 ? 1.75 : GameConfig.stuntNearMissMultiplier);
        points = (points * mult).toInt();
      } else if (game.plane.planeType == PlaneType.ninjaStar) {
        final mult = game.plane.planeLevel >= 3 ? 1.60 : (game.plane.planeLevel == 2 ? 1.45 : 1.30);
        points = (points * mult).toInt();
      }
    } catch (_) {}
    _nearMissScoreAccumulated += points;
    // Damage/crumple feedback on the plane model.
    try {
      game.plane.onNearMiss(tier);
    } catch (_) {}

    final spawnPos = position ?? game.plane.position.clone();
    spawnNearMissFeedback(game, spawnPos, tier, points);
    // Juice: sharp medium click on a confirmed near-miss (Task 6).
    game.gameFeelSystem.onNearMiss();
    // Death Defying earns the full drama: micro hit-stop + camera pulse.
    if (tier == NearMissTier.deathDefying) {
      game.triggerDeathDefyingSlowMo();
    }
    return points;
  }

  /// Call by streak trackers (smooth glide, thermal surf) to bank flat
  /// bonus points. Albatross earns 2x..3x streak bonus!
  void awardStreakBonus(int points) {
    var finalPoints = points;
    try {
      if (game.plane.planeType == PlaneType.albatross) {
        final mult = game.plane.planeLevel >= 3
            ? 3.0
            : (game.plane.planeLevel == 2 ? 2.5 : 2.0);
        finalPoints = (finalPoints * mult).toInt();
      }
    } catch (_) {}
    _streakScoreAccumulated += finalPoints;
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
