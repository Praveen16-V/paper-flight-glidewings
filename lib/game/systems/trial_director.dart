import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../models/trial_definition.dart';
import '../../providers/game_session_provider.dart';
import '../components/obstacles/obstacle_script.dart';
import '../paper_flight_game.dart';

/// Plays out a handcrafted Precision Trial course.
///
/// The director owns everything that makes trials different from endless:
///  - emits scripted obstacle/coin spawns exactly when the world scroll
///    reaches each course element (converting "distance at plane row" into
///    "distance at spawn" via the fixed course speed);
///  - runs the trial clock (par time) and fails the run on timeout;
///  - plants scripted turbulence pockets;
///  - evaluates the star rating when the course is completed.
class TrialDirector extends Component with HasGameRef<PaperFlightGame> {
  TrialDirector({required this.trial}) : _timeLeft = trial.parSeconds ?? 0;

  final TrialDefinition trial;

  double _timeLeft;
  double get timeLeft => _timeLeft;

  /// Seconds the plane has spent in this course (derived from the fixed
  /// scroll speed — frame-rate independent).
  double get timeUsedSeconds {
    final speedMetersPerSec = gameRef.scrollSpeed / 10.0;
    return speedMetersPerSec <= 0
        ? 0
        : gameRef.distanceMeters / speedMetersPerSec;
  }

  int _stepIndex = 0;
  int _turbulenceIndex = 0;
  bool _ended = false;

  @override
  void update(double dt) {
    if (gameRef.phase != GamePhase.playing) return;
    if (_ended) return;

    // ── Trial clock ─────────────────────────────────────────────────────────
    final par = trial.parSeconds;
    if (par != null) {
      _timeLeft -= dt;
      gameRef.ref
          .read(gameSessionProvider.notifier)
          .updateTrialTime(_timeLeft.clamp(0.0, 9999.0));
      if (_timeLeft <= 0) {
        _ended = true;
        gameRef.onTrialTimeout();
        return;
      }
    }

    // ── Scripted turbulence pockets ─────────────────────────────────────────
    while (_turbulenceIndex < trial.turbulence.length &&
        gameRef.distanceMeters >=
            trial.turbulence[_turbulenceIndex].startMeters) {
      final t = trial.turbulence[_turbulenceIndex];
      // Convert the (start..end) distance window into a pocket lifetime at
      // the course's fixed speed: meters → px → seconds.
      final distancePx = (t.endMeters - t.startMeters) * 10.0;
      final ttlSeconds =
          gameRef.scrollSpeed <= 0 ? 1.0 : distancePx / gameRef.scrollSpeed;
      gameRef.windSystem.addTurbulencePocket(
        t.normX,
        t.radius,
        ttlSeconds,
      );
      _turbulenceIndex++;
    }

    // ── Scripted course elements ────────────────────────────────────────────
    while (_stepIndex < trial.steps.length &&
        gameRef.distanceMeters >= _spawnDistance(trial.steps[_stepIndex])) {
      _emitStep(trial.steps[_stepIndex]);
      _stepIndex++;
    }

    // ── Course complete ─────────────────────────────────────────────────────
    if (_stepIndex >= trial.steps.length &&
        gameRef.distanceMeters >= trial.courseEndMeters) {
      _ended = true;
      gameRef.onTrialComplete();
    }
  }

  /// Converts a "reaches the plane row" distance into the spawn moment,
  /// accounting for the vertical travel from the spawn line to the plane row.
  double _spawnDistance(TrialStep step) {
    // Coin-only steps spawn from the coin line (-40) which is closer to the
    // plane row than the obstacle line (-80).
    var lead = step.items.any((i) => i is TrialObstacleSpawn)
        ? GameConfig.trialObstacleLeadMeters
        : GameConfig.trialCoinLeadMeters;
    for (final item in step.items) {
      if (item is TrialObstacleSpawn) {
        final early = item.type == ObstacleType.drone ||
            item.type == ObstacleType.bird ||
            item.type == ObstacleType.stormCloud;
        if (early && lead < GameConfig.trialEarlyWarningLeadMeters) {
          lead = GameConfig.trialEarlyWarningLeadMeters;
        }
      }
    }
    return step.atMeters - lead;
  }

  void _emitStep(TrialStep step) {
    for (final item in step.items) {
      switch (item) {
        case TrialObstacleSpawn():
          final script = ObstacleScript(
            gapCenterX: item.gapCenterX,
            gapWidth: item.gapWidth,
            driftAmp: item.driftAmp,
            driftFreq: item.driftFreq,
            fromLeft: item.fromLeft,
          );
          gameRef.obstacleSpawner.spawnScripted(
            item.type,
            x: item.x,
            script: script,
          );
        case TrialCoinSpawn():
          gameRef.collectibleSpawner.spawnCoinAt(
            Vector2(item.x, GameConfig.coinSpawnY),
          );
        case TrialCoinLineSpawn(:final count, :final spacing):
          gameRef.collectibleSpawner.spawnCoinLine(
            x: item.x,
            startY: GameConfig.coinSpawnY,
            count: count,
            spacing: spacing,
          );
        case TrialCoinArcSpawn(:final radius, :final count):
          gameRef.collectibleSpawner.spawnCoinArc(
            centerX: item.centerX,
            startY: GameConfig.coinSpawnY,
            radius: radius,
            count: count,
          );
      }
    }
  }

  /// 0–3 stars for the completed course.
  int evaluateStars() {
    final metric = trial.starMetric;
    final double value = switch (metric) {
      TrialStarMetric.timeRemaining => _timeLeft,
      TrialStarMetric.coinsPercent => _coinFraction,
    };
    return trial.starsFor(value);
  }

  double get _coinFraction {
    final total = trial.countCoins();
    if (total <= 0) return 1.0;
    final collected = gameRef.ref.read(gameSessionProvider).coinsThisRun;
    return (collected / total).clamp(0.0, 1.0);
  }
}
