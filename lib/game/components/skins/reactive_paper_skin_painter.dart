import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show PaintingStyle;

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';

/// Holds short-lived gameplay reactions for the currently equipped paper skin.
///
/// PlaneComponent owns one painter and forwards game events through
/// [onGameEvent]. Keeping the state here avoids coupling collectible, obstacle,
/// and shield systems to a particular skin implementation.
class ReactivePaperSkinPainter {
  ReactivePaperSkinPainter(this._skin);

  PaperSkin _skin;
  double _goldCoinSparkleTimer = 0;
  double _holographicShiftTimer = 0;
  double _dragonShieldPulseTimer = 0;

  PaperSkin get skin => _skin;

  void setSkin(PaperSkin value) {
    if (_skin == value) return;
    _skin = value;
    reset();
  }

  void reset() {
    _goldCoinSparkleTimer = 0;
    _holographicShiftTimer = 0;
    _dragonShieldPulseTimer = 0;
  }

  /// Reacts to a flight event only when this skin owns a matching effect.
  void onGameEvent(SkinGameEvent eventType) {
    switch (eventType) {
      case SkinGameEvent.coinCollected:
        if (_skin == PaperSkin.goldLeaf) {
          _goldCoinSparkleTimer = GameConfig.goldLeafCoinSparkleDuration;
        }
        break;
      case SkinGameEvent.nearMiss:
        if (_skin == PaperSkin.holographicFoil) {
          _holographicShiftTimer =
              GameConfig.holographicNearMissShiftDuration;
        }
        break;
      case SkinGameEvent.shieldHit:
        if (_skin == PaperSkin.dragonScales) {
          _dragonShieldPulseTimer =
              GameConfig.dragonScaleShieldPulseDuration;
        }
        break;
    }
  }

  void update(double dt) {
    _goldCoinSparkleTimer =
        math.max(0.0, _goldCoinSparkleTimer - dt).toDouble();
    _holographicShiftTimer =
        math.max(0.0, _holographicShiftTimer - dt).toDouble();
    _dragonShieldPulseTimer =
        math.max(0.0, _dragonShieldPulseTimer - dt).toDouble();
  }

  double get goldCoinSparkleIntensity => _fraction(
        _goldCoinSparkleTimer,
        GameConfig.goldLeafCoinSparkleDuration,
      );

  double get holographicNearMissIntensity => _fraction(
        _holographicShiftTimer,
        GameConfig.holographicNearMissShiftDuration,
      );

  double get dragonShieldPulseIntensity => _fraction(
        _dragonShieldPulseTimer,
        GameConfig.dragonScaleShieldPulseDuration,
      );

  /// Near misses briefly rotate Holographic Foil through a different palette.
  double get holographicHueShiftDegrees =>
      holographicNearMissIntensity * 180.0;

  /// Draws small reaction-only particles/rings after the base skin pattern.
  void renderReactionOverlay(Canvas canvas, double w, double h, double time) {
    if (_skin == PaperSkin.goldLeaf && goldCoinSparkleIntensity > 0.01) {
      _drawGoldCoinSparkles(canvas, w, h, time);
    }
    if (_skin == PaperSkin.dragonScales && dragonShieldPulseIntensity > 0.01) {
      _drawDragonShieldPulse(canvas, w, h);
    }
  }

  void _drawGoldCoinSparkles(Canvas canvas, double w, double h, double time) {
    final intensity = goldCoinSparkleIntensity;
    final center = Offset(w / 2, h / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 9; i++) {
      final angle = i.toDouble() * (math.pi * 2 / 9) + time * 5.0;
      final travel =
          9.0 + (1.0 - intensity) * 17.0 + (i % 3).toDouble() * 2.5;
      final x = center.dx + math.cos(angle) * travel;
      final y = center.dy + math.sin(angle) * travel * .62;
      final radius = 1.1 + intensity * 1.9 + (i.isEven ? .5 : 0.0);
      paint.color = Color.fromRGBO(
        255,
        249,
        196,
        (.32 + intensity * .68).clamp(0.0, 1.0).toDouble(),
      );
      canvas.drawCircle(Offset(x, y), radius, paint);
      if (i % 3 == 0) {
        final ray = Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8 + intensity;
        canvas.drawLine(Offset(x - radius * 2, y), Offset(x + radius * 2, y), ray);
        canvas.drawLine(Offset(x, y - radius * 2), Offset(x, y + radius * 2), ray);
      }
    }
  }

  void _drawDragonShieldPulse(Canvas canvas, double w, double h) {
    final intensity = dragonShieldPulseIntensity;
    final center = Offset(w / 2, h / 2);
    final ring = Paint()
      ..color = Color.fromRGBO(
        178,
        255,
        89,
        (.18 + intensity * .58).clamp(0.0, .76).toDouble(),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + intensity * 2.2;
    canvas.drawCircle(center, w * (.34 + (1.0 - intensity) * .28), ring);
  }

  double _fraction(double remaining, double duration) {
    if (duration <= 0) return 0.0;
    return (remaining / duration).clamp(0.0, 1.0).toDouble();
  }
}
