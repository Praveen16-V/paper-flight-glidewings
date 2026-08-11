import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../components/effects/thermal_column_component.dart';
import '../paper_flight_game.dart';

/// A physics sample from the strongest visible thermal column at a position.
class ThermalColumnSample {
  const ThermalColumnSample({
    required this.column,
    required this.influence,
    required this.lift,
  });

  final ThermalColumnComponent column;
  final double influence;
  final double lift;

  ThermalSurfUpdate trackPilot(Vector2 position, double dt) =>
      column.trackPilot(position, dt);
}

/// Converts broad favourable wind lanes into a small number of visible,
/// flyable thermal columns. This keeps the underlying lane generator useful for
/// weather pacing while making the actual lift a local skill target.
class ThermalColumnSystem extends Component {
  ThermalColumnSystem({
    required this.game,
    int? seed,
  }) : _rng = math.Random(seed ?? 31);

  final PaperFlightGame game;
  final math.Random _rng;
  late final List<ThermalColumnComponent> _columns;

  List<ThermalColumnComponent> get columns =>
      List<ThermalColumnComponent>.unmodifiable(_columns);

  @override
  Future<void> onLoad() async {
    _columns = List.generate(
      GameConfig.windLaneCount,
      (lane) => ThermalColumnComponent(
        laneIndex: lane,
        particleSeed: _rng.nextInt(1 << 31),
      ),
    );
    for (final column in _columns) {
      add(column);
    }
    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase == GamePhase.playing) {
      _syncColumnsToWind();
    } else {
      for (final column in _columns) {
        column.fadeOut();
      }
    }
    super.update(dt);
  }

  /// Finds the strongest local lift. There is normally at most one matching
  /// column, but selecting the strongest keeps transitions graceful if two
  /// adjacent lane columns briefly overlap at their soft edges.
  ThermalColumnSample? sampleAt(Vector2 position) {
    ThermalColumnSample? strongest;
    for (final column in _columns) {
      final influence = column.influenceAt(position);
      if (influence <= 0) continue;
      final lift = column.liftAt(position);
      if (lift < GameConfig.thermalColumnMinimumLift) continue;
      if (strongest == null || lift > strongest.lift) {
        strongest = ThermalColumnSample(
          column: column,
          influence: influence,
          lift: lift,
        );
      }
    }
    return strongest;
  }

  void reset() {
    for (final column in _columns) {
      column.deactivate();
    }
  }

  void _syncColumnsToWind() {
    final wind = game.windSystem;
    final windCallerOwnsTheAir = wind.windCallerActive;

    for (var lane = 0; lane < GameConfig.windLaneCount; lane++) {
      final column = _columns[lane];
      final laneWind = wind.windAt(lane);
      final shouldFormColumn = !windCallerOwnsTheAir &&
          laneWind.type == WindType.thermal &&
          laneWind.liftBonus >= GameConfig.thermalColumnMinimumLift;

      if (!shouldFormColumn) {
        column.fadeOut();
        continue;
      }

      if (!column.isActive) {
        final radius = _nextRadius();
        column.activate(
          centerX: _nextCenterForLane(lane, radius),
          radius: radius,
          lift: laneWind.liftBonus,
        );
      } else {
        column.refresh(laneWind.liftBonus);
      }
    }
  }

  double _nextRadius() => GameConfig.thermalColumnMinRadius +
      _rng.nextDouble() *
          (GameConfig.thermalColumnMaxRadius -
              GameConfig.thermalColumnMinRadius);

  double _nextCenterForLane(int lane, double radius) {
    final laneWidth = GameConfig.designWidth / GameConfig.windLaneCount;
    final laneLeft = lane * laneWidth;

    // Trial courses are authored around lane centres. Endless/Daily columns
    // vary their location within a lane to stay local and replayable.
    if (game.mode == GameMode.trial) return laneLeft + laneWidth * .5;

    final marginFraction =
        ((radius + 4) / laneWidth).clamp(.12, .45).toDouble();
    final availableFraction = 1.0 - marginFraction * 2;
    return laneLeft +
        laneWidth *
            (marginFraction + _rng.nextDouble() * availableFraction);
  }
}
