import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';

/// Adapts obstacle pacing to how confidently the current flight is going.
///
/// This intentionally works only inside a single Classic/Daily run: it rewards
/// demonstrated control (combos and near-misses) without quietly converting a
/// player's lifetime save data into a permanent punishment. Shield/decoy/Crane
/// saves produce temporary relief, while normal distance progression still
/// ensures a long successful flight earns a livelier sky.
class DynamicDifficultySystem extends Component {
  DynamicDifficultySystem({required this.game});

  final PaperFlightGame game;

  double _intensity = GameConfig.dynamicDifficultyBaseIntensity;
  double _nearMissMomentum = 0.0;
  double _safetyRelief = 0.0;

  /// Smoothed 0..1 run intensity used by spawners and diagnostic UI.
  double get intensity => _intensity;
  double get nearMissMomentum => _nearMissMomentum;
  double get safetyRelief => _safetyRelief;

  bool get isAdaptiveMode =>
      game.mode == GameMode.classic || game.mode == GameMode.daily;

  /// Multiplies ordinary obstacle intervals. Skilled, composed runs shrink the
  /// interval; a recent safety intervention grants a temporary wider gap.
  double get spawnIntervalMultiplier => isAdaptiveMode
      ? GameConfig.dynamicDifficultySpawnIntervalMultiplier(_intensity)
      : 1.0;

  /// Curated patterns stay rare, but become more available to pilots already
  /// proving they can read density and telegraphs.
  double get combinationChanceMultiplier => isAdaptiveMode
      ? GameConfig.dynamicDifficultyCombinationChanceMultiplier(_intensity)
      : 1.0;

  /// Biases only pressure-oriented types. Bosses keep their authored rarity,
  /// and familiar structural hazards remain stable anchors in the mix.
  double obstacleWeightMultiplier(ObstacleType type) {
    if (!isAdaptiveMode || type.isBoss) return 1.0;

    final multiplier = switch (type) {
      ObstacleType.lightningStrike ||
      ObstacleType.meteorShower ||
      ObstacleType.tornado ||
      ObstacleType.stormCloud => 0.80 + _intensity * 0.55,
      ObstacleType.drone ||
      ObstacleType.trafficPlane ||
      ObstacleType.bird ||
      ObstacleType.flockMigration ||
      ObstacleType.kite ||
      ObstacleType.windTurbine ||
      ObstacleType.whaleBreach => 0.92 + _intensity * 0.32,
      _ => 1.0,
    };
    return multiplier.clamp(0.78, 1.32).toDouble();
  }

  /// Called after a confirmed near-miss, never while the objects are still
  /// converging. Riskier passes build more momentum than a routine close shave.
  void registerNearMiss(NearMissTier tier) {
    if (!isAdaptiveMode) return;
    final gain = switch (tier) {
      NearMissTier.closeShave => GameConfig.dynamicDifficultyCloseShaveMomentum,
      NearMissTier.hairThin => GameConfig.dynamicDifficultyHairThinMomentum,
      NearMissTier.deathDefying =>
        GameConfig.dynamicDifficultyDeathDefyingMomentum,
    };
    _nearMissMomentum = (_nearMissMomentum + gain).clamp(0.0, 1.0).toDouble();
  }

  /// Called whenever a non-terminal defensive resource has to save the flight.
  /// [severity] lets a consumed shield provide a bit more breathing room than a
  /// reflected projectile, while keeping all relief bounded and temporary.
  void registerSafetyIntervention({double severity = 1.0}) {
    if (!isAdaptiveMode) return;
    _safetyRelief = (_safetyRelief +
            GameConfig.dynamicDifficultySafetyReliefPerHit *
                severity.clamp(0.0, 1.0))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void reset() {
    _intensity = GameConfig.dynamicDifficultyBaseIntensity;
    _nearMissMomentum = 0.0;
    _safetyRelief = 0.0;
  }

  @override
  void update(double dt) {
    if (!isAdaptiveMode) {
      reset();
      return;
    }
    if (game.phase != GamePhase.playing) return;

    _nearMissMomentum = (_nearMissMomentum -
            GameConfig.dynamicDifficultyMomentumDecayPerSecond * dt)
        .clamp(0.0, 1.0)
        .toDouble();
    _safetyRelief = (_safetyRelief -
            GameConfig.dynamicDifficultySafetyReliefDecayPerSecond * dt)
        .clamp(0.0, 1.0)
        .toDouble();

    final target = GameConfig.dynamicDifficultyTarget(
      distanceMeters: game.distanceMeters,
      comboGaugeFraction: game.scoringSystem.comboGaugeFraction,
      nearMissMomentum: _nearMissMomentum,
      safetyRelief: _safetyRelief,
    );
    final blend = (GameConfig.dynamicDifficultyResponsePerSecond * dt)
        .clamp(0.0, 1.0)
        .toDouble();
    _intensity = MathUtils.lerp(_intensity, target, blend);
  }
}
