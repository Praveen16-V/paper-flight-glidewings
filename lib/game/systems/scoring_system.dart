import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
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
  int _comboCount = 0;
  double _comboMultiplier = 1.0;
  int _coinScoreAccumulated = 0;

  int get score => _score;
  int get coinsThisRun => _coinsThisRun;
  int get nearMissesThisRun => _nearMissesThisRun;
  int get comboCount => _comboCount;
  double get comboMultiplier => _comboMultiplier;

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
    _comboMultiplier = 1.0 + (_comboCount * GameConfig.comboMultiplierStep);
    _coinsThisRun++;
    final points = (_comboMultiplier * 10).toInt();
    _coinScoreAccumulated += points;

    // Immediate HUD push for snappy feedback.
    final notifier = game.ref.read(gameSessionProvider.notifier);
    notifier.updateCoins(_coinsThisRun);
    notifier.updateCombo(_comboCount, _comboMultiplier);
    notifier.updateScore(
      (game.distanceMeters * GameConfig.scorePerMeter).toInt() +
          _coinScoreAccumulated +
          _nearMissesThisRun * GameConfig.nearMissPoints,
    );

    return points;
  }

  /// Call when the plane hits an obstacle (combo resets; coin tally keeps).
  void onObstacleHit() {
    _comboCount = GameConfig.coinComboResetOnHit;
    _comboMultiplier = 1.0;
    game.ref
        .read(gameSessionProvider.notifier)
        .updateCombo(_comboCount, _comboMultiplier);
  }

  /// Call when a near-miss is detected.
  int onNearMiss() {
    _nearMissesThisRun++;
    game.ref.read(gameSessionProvider.notifier).addNearMiss();
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

  /// Restore scoring state after a revive (new FlameGame instance).
  void restore({
    required int coins,
    required int nearMisses,
    required int comboCount,
    required double comboMultiplier,
    required int coinScoreHint,
  }) {
    _coinsThisRun = coins;
    _nearMissesThisRun = nearMisses;
    _comboCount = comboCount;
    _comboMultiplier = comboMultiplier;
    // Approximate coin score contribution from total score hint.
    final distScore = (game.distanceMeters * GameConfig.scorePerMeter).toInt();
    final nearScore = nearMisses * GameConfig.nearMissPoints;
    _coinScoreAccumulated =
        (coinScoreHint - distScore - nearScore).clamp(0, coinScoreHint).toInt();
    _score = coinScoreHint;
    _pushTimer = 0;
  }
}
