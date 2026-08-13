import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../components/effects/coin_feedback.dart';
import '../components/wingman_component.dart';
import '../paper_flight_game.dart';

/// Manages friendly AI wingmen in Zen and Daily Flight.
///
/// The planes never collide with hazards or collect items themselves. They are
/// a precision companion mechanic: fly smoothly enough to keep them close and
/// the squad builds combo support plus a bonus to coin value.
class WingmanSystem extends Component {
  WingmanSystem({
    required this.game,
    int? seed,
  }) : _rng = math.Random(seed ?? 73);

  final PaperFlightGame game;
  final math.Random _rng;
  late final List<WingmanComponent> _wingmen;

  bool _launched = false;
  bool _formationActive = false;
  double _formationHoldSeconds = 0;
  double _outOfRangeSeconds = 0;
  double _comboPulseTimer = 0;

  List<WingmanComponent> get wingmen =>
      List<WingmanComponent>.unmodifiable(_wingmen);
  bool get isFormationActive => _formationActive && _modeSupportsWingmen;
  double get coinScoreMultiplier => isFormationActive
      ? GameConfig.wingmanCoinScoreMultiplier
      : 1.0;

  @override
  Future<void> onLoad() async {
    const tints = <Color>[
      Color(0xFF80DEEA),
      Color(0xFFFFCC80),
      Color(0xFFA5D6A7),
      Color(0xFFCE93D8),
    ];
    _wingmen = List.generate(
      GameConfig.wingmanCount,
      (index) => WingmanComponent(
        formationOffset: _offsetFor(index),
        tint: tints[index % tints.length],
        seed: _rng.nextInt(1 << 31),
      ),
    );
    for (final wingman in _wingmen) {
      add(wingman);
    }
    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing || !_modeSupportsWingmen) {
      _deactivateFormation();
      super.update(dt);
      return;
    }

    final leaderPosition = game.plane.position;
    if (!_launched) {
      for (final wingman in _wingmen) {
        wingman.activate(leaderPosition);
      }
      _launched = true;
    }

    for (final wingman in _wingmen) {
      wingman.followLeader(leaderPosition, dt);
    }

    final squadClose =
        _wingmen.every((wingman) => wingman.isNearLeader(leaderPosition));
    _updateFormationState(dt, squadClose);
    super.update(dt);
  }

  void reset() {
    _deactivateFormation();
  }

  void _updateFormationState(double dt, bool squadClose) {
    if (squadClose) {
      _outOfRangeSeconds = 0;
      _formationHoldSeconds += dt;
    } else {
      _outOfRangeSeconds += dt;
      if (_outOfRangeSeconds >= GameConfig.wingmanFormationGraceSeconds) {
        _formationHoldSeconds = 0;
        _comboPulseTimer = 0;
        if (_formationActive) {
          _formationActive = false;
          _setWingmanLock(false);
        }
      }
    }

    if (!_formationActive &&
        _formationHoldSeconds >= GameConfig.wingmanFormationJoinSeconds) {
      _formationActive = true;
      _comboPulseTimer = 0;
      _setWingmanLock(true);
      spawnStreakFeedback(
        game,
        game.plane.position.clone()..add(Vector2(0, -52)),
        'FORMATION LOCK!',
        const Color(0xFF80DEEA),
      );
    }

    if (!isFormationActive) return;

    _comboPulseTimer += dt;
    if (_comboPulseTimer < GameConfig.wingmanComboPulseInterval) return;
    _comboPulseTimer = 0;
    game.scoringSystem.awardComboNotches(
      GameConfig.wingmanComboBonusNotches,
    );
    spawnStreakFeedback(
      game,
      game.plane.position.clone()..add(Vector2(0, -52)),
      '+${GameConfig.wingmanComboBonusNotches.toStringAsFixed(1)} FORMATION COMBO',
      const Color(0xFFB9F6CA),
    );
  }

  void _deactivateFormation() {
    if (!_launched && !_formationActive) return;
    for (final wingman in _wingmen) {
      wingman.deactivate();
    }
    _launched = false;
    _formationActive = false;
    _formationHoldSeconds = 0;
    _outOfRangeSeconds = 0;
    _comboPulseTimer = 0;
  }

  void _setWingmanLock(bool locked) {
    for (final wingman in _wingmen) {
      wingman.setFormationLocked(locked);
    }
  }

  bool get _modeSupportsWingmen =>
      game.mode == GameMode.zen || game.mode == GameMode.daily;

  Vector2 _offsetFor(int index) {
    final side = index.isEven ? -1.0 : 1.0;
    final rank = index ~/ 2;
    return Vector2(
      side * (66.0 + rank * 25.0),
      28.0 + rank * 18.0,
    );
  }
}
