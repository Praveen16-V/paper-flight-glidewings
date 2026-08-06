import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
import '../components/effects/coin_feedback.dart';
import '../paper_flight_game.dart';

/// Owns all score calculation and pushes updates to [gameSessionProvider].
///
/// Score formula (per GDD §6):
///   distance_score   = distanceMeters × scorePerMeter
///   coin_score       = coinsCollected × comboMultiplier (at time of pickup)
///   near_miss_bonus  = nearMisses × nearMissPoints
///   total            = sum of all above
class ScoringSystem extends Component {
  ScoringSystem({required this.game});

  final PaperFlightGame game;

  int _score = 0;
  int _coinsThisRun = 0;
  int _nearMissesThisRun = 0;
  int _comboCount = 0;        // consecutive coins without hitting anything
  double _comboMultiplier = 1.0;

  int get score => _score;
  int get coinsThisRun => _coinsThisRun;
  int get nearMissesThisRun => _nearMissesThisRun;
  int get comboCount => _comboCount;
  double get comboMultiplier => _comboMultiplier;

  // How frequently (in seconds) we push score to provider.
  static const double _pushInterval = 0.1;
  double _pushTimer = 0;

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;

    // Distance-based score accumulates continuously.
    final distScore = (game.distanceMeters * GameConfig.scorePerMeter).toInt();
    final coinScore = _coinScoreAccumulated;
    final nearScore = _nearMissesThisRun * GameConfig.nearMissPoints;
    _score = distScore + coinScore + nearScore;

    _pushTimer += dt;
    if (_pushTimer >= _pushInterval) {
      _pushTimer = 0;
      final notifier = game.ref.read(gameSessionProvider.notifier);
      notifier.updateScore(_score);
      notifier.updateCoins(_coinsThisRun);
      notifier.updateCombo(_comboCount, _comboMultiplier);
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call when a coin is collected. Returns the points awarded.
  int onCoinCollected() {
    _comboCount++;
    if (_comboCount > GameConfig.comboMax) {
      _comboCount = GameConfig.comboMax;
    }
    _comboMultiplier =
        1.0 + (_comboCount * GameConfig.comboMultiplierStep);
    _coinsThisRun++;
    var points = (_comboMultiplier * 10).toInt();
    // Coin Rush: every coin is worth 2× for the duration of the power-up.
    final session = game.ref.read(gameSessionProvider);
    if (session.activePowerUps.contains(PowerUpType.coinRush)) {
      points = (points * GameConfig.coinRushValueMultiplier).toInt();
    }
    _coinScoreAccumulated += points;
    return points;
  }

  /// Call when the plane hits an obstacle (and is not shielded).
  void onObstacleHit() {
    _comboCount = GameConfig.coinComboResetOnHit;
    _comboMultiplier = 1.0;
    _coinScoreAccumulated = 0; // doesn't reset accumulated coins, just the future multiplier
  }

  /// Call when a near-miss is detected.
  int onNearMiss({Vector2? position}) {
    _nearMissesThisRun++;
    game.ref.read(gameSessionProvider.notifier).addNearMiss();
    final spawnPos = position ?? game.plane.position.clone();
    spawnNearMissFeedback(game, spawnPos, GameConfig.nearMissPoints);
    return GameConfig.nearMissPoints;
  }

  void reset() {
    _score = 0;
    _coinsThisRun = 0;
    _nearMissesThisRun = 0;
    _comboCount = 0;
    _comboMultiplier = 1.0;
    _coinScoreAccumulated = 0;
    _pushTimer = 0;
  }

  // ── Internal accumulators ──────────────────────────────────────────────────

  int _coinScoreAccumulated = 0;
}
