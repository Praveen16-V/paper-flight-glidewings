import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../components/effects/coin_feedback.dart';
import '../paper_flight_game.dart';

/// Tracks "Clean Flight" streaks and pays escalating flat bonuses via
/// [ScoringSystem.awardStreakBonus].
///
/// Two independent streaks:
///
///  * **Smooth Glide** — consecutive seconds spent in the released glide
///    state without touching lift and without hard steering reversals
///    (over-correcting). Pays `cleanFlightBasePoints × streakSecond` each
///    full second, capped at [GameConfig.cleanFlightMaxEscalation].
///    In touch-based schemes the streak only accumulates while hands-off —
///    it rewards letting the plane soar through its glide arcs.
///
///  * **Thermal Surf** — consecutive seconds riding a thermal updraft lane.
///    Pays `thermalSurfBasePoints × streakSecond` each full second, capped at
///    [GameConfig.thermalSurfMaxEscalation]. Resets the instant the plane
///    leaves the thermal.
class StreakSystem extends Component with HasGameRef<PaperFlightGame> {
  // ── Smooth Glide state ─────────────────────────────────────────────────────
  double _glideSeconds = 0;
  int _glideTicksPaid = 0;

  /// Last committed steering direction (-1 left, +1 right, 0 neutral). A
  /// flip while fully committed is what we call an over-correction.
  int _steerSign = 0;

  // ── Thermal Surf state ─────────────────────────────────────────────────────
  double _thermalSeconds = 0;
  int _thermalTicksPaid = 0;

  void reset() {
    _glideSeconds = 0;
    _glideTicksPaid = 0;
    _steerSign = 0;
    _thermalSeconds = 0;
    _thermalTicksPaid = 0;
  }

  @override
  void update(double dt) {
    if (gameRef.phase != GamePhase.playing) return;
    _updateSmoothGlide(dt);
    _updateThermalSurf(dt);
  }

  // ── Smooth Glide ───────────────────────────────────────────────────────────

  void _updateSmoothGlide(double dt) {
    final input = gameRef.inputManager;

    // Over-correction detection: only a committed direction followed by a
    // committed reversal counts — wobbling inside the hysteresis band is
    // still "smooth".
    var overCorrected = false;
    final h = input.horizontalInput;
    if (h.abs() >= GameConfig.overCorrectionInputThreshold) {
      final sign = h > 0 ? 1 : -1;
      if (_steerSign != 0 && sign != _steerSign) {
        overCorrected = true;
      }
      _steerSign = sign;
    } else if (h.abs() <= GameConfig.overCorrectionReleaseThreshold) {
      _steerSign = 0; // released back to neutral
    }

    if (input.isHolding || overCorrected) {
      _breakGlideStreak();
      return;
    }

    _glideSeconds += dt;
    final wholeSeconds = _glideSeconds.floor();
    if (wholeSeconds > _glideTicksPaid) {
      _glideTicksPaid = wholeSeconds;
      final tier = wholeSeconds > GameConfig.cleanFlightMaxEscalation
          ? GameConfig.cleanFlightMaxEscalation
          : wholeSeconds;
      final points = GameConfig.cleanFlightBasePoints * tier;
      gameRef.scoringSystem.awardStreakBonus(points);
      spawnStreakFeedback(
        gameRef,
        _streakTextPosition(),
        '+$points CLEAN FLIGHT',
        const Color(0xFF4FC3F7), // airy cyan
      );
    }
  }

  void _breakGlideStreak() {
    _glideSeconds = 0;
    _glideTicksPaid = 0;
  }

  // ── Thermal Surf ───────────────────────────────────────────────────────────

  void _updateThermalSurf(double dt) {
    if (!gameRef.plane.isInThermal) {
      _thermalSeconds = 0;
      _thermalTicksPaid = 0;
      return;
    }

    _thermalSeconds += dt;
    final wholeSeconds = _thermalSeconds.floor();
    if (wholeSeconds > _thermalTicksPaid) {
      _thermalTicksPaid = wholeSeconds;
      final tier = wholeSeconds > GameConfig.thermalSurfMaxEscalation
          ? GameConfig.thermalSurfMaxEscalation
          : wholeSeconds;
      final points = GameConfig.thermalSurfBasePoints * tier;
      gameRef.scoringSystem.awardStreakBonus(points);
      spawnStreakFeedback(
        gameRef,
        _streakTextPosition(),
        '+$points THERMAL SURF',
        const Color(0xFFFFD54F), // thermal gold
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Streak texts float above the plane so they never stack on top of the
  /// coin / near-miss banners anchored at the plane itself.
  Vector2 _streakTextPosition() {
    return gameRef.plane.position.clone()..add(Vector2(0, -38));
  }
}
