import 'dart:ui';

import 'package:flutter/painting.dart' show PaintingStyle;

import '../../../core/enums/game_enums.dart';

/// Blends a pristine skin into its veteran paper variant from a persistent wear
/// level. The marks are deterministic per skin, so a player's aircraft gains a
/// recognisable history rather than flickering random damage every frame.
class WeatheredPaperSkinPainter {
  const WeatheredPaperSkinPainter();

  static const double pristineThreshold = .18;
  static const double veteranThreshold = .68;

  String variantLabel(double wearLevel) {
    if (wearLevel < pristineThreshold) return 'PRISTINE';
    if (wearLevel < veteranThreshold) return 'SEASONED';
    return 'VETERAN';
  }

  void paint(
    Canvas canvas, {
    required PaperSkin skin,
    required double wearLevel,
    required double width,
    required double height,
  }) {
    final veteranBlend = wearLevel.clamp(0.0, 1.0).toDouble();
    if (veteranBlend <= .01) return;
    final seed = skin.index;

    // Stains blend in first, preserving the base skin's identity beneath a
    // translucent, warm paper patina.
    final stainPaint = Paint()
      ..color = Color.fromRGBO(
        91,
        63,
        45,
        (.05 + veteranBlend * .18).clamp(0.0, .24).toDouble(),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 3; i++) {
      final x = width *
          (.24 + ((seed + i * 3) % 6).toDouble() * .11);
      final y = height *
          (.30 + ((seed * 2 + i * 5) % 5).toDouble() * .10);
      canvas.drawCircle(
        Offset(x, y),
        2.5 + veteranBlend * (4.0 + i),
        stainPaint,
      );
    }

    // Veteran fold creases become more visible as the pristine overlay blends
    // out. The paired light/dark strokes keep them paper-like rather than dirt.
    final foldShadow = Paint()
      ..color = Color.fromRGBO(
        52,
        42,
        35,
        (.10 + veteranBlend * .36).clamp(0.0, .48).toDouble(),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65 + veteranBlend * 1.15;
    final foldHighlight = Paint()
      ..color = Color.fromRGBO(
        255,
        248,
        225,
        (.10 + veteranBlend * .24).clamp(0.0, .34).toDouble(),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = .45 + veteranBlend * .65;
    final foldA = Path()
      ..moveTo(width * .16, height * .24)
      ..quadraticBezierTo(width * .48, height * .44, width * .84, height * .70);
    final foldB = Path()
      ..moveTo(width * .12, height * .76)
      ..quadraticBezierTo(width * .46, height * .58, width * .88, height * .32);
    canvas.drawPath(foldA, foldShadow);
    canvas.drawPath(foldB, foldShadow);
    canvas.drawPath(foldA.shift(const Offset(0, -.65)), foldHighlight);
    canvas.drawPath(foldB.shift(const Offset(0, -.65)), foldHighlight);

    // Micro-tears remain restrained at low wear, then show ragged edge marks
    // and a small paper nick on fully veteran sheets.
    final tearPaint = Paint()
      ..color = Color.fromRGBO(
        66,
        43,
        30,
        (.08 + veteranBlend * .45).clamp(0.0, .56).toDouble(),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7 + veteranBlend * .9
      ..strokeCap = StrokeCap.round;
    final tearCount = 1 + (veteranBlend * 4).floor();
    for (var i = 0; i < tearCount; i++) {
      final y = height * (.22 + i.toDouble() * .15);
      final leftTear = Path()
        ..moveTo(width * .08, y)
        ..lineTo(width * (.13 + veteranBlend * .05), y + 1.8)
        ..lineTo(width * .09, y + 3.8);
      canvas.drawPath(leftTear, tearPaint);
      if (i.isEven) {
        final rightTear = Path()
          ..moveTo(width * .92, height - y)
          ..lineTo(width * (.87 - veteranBlend * .05), height - y - 1.8)
          ..lineTo(width * .91, height - y - 3.8);
        canvas.drawPath(rightTear, tearPaint);
      }
    }

    if (veteranBlend >= veteranThreshold) {
      final nick = Path()
        ..moveTo(width * .72, height * .12)
        ..lineTo(width * .80, height * .18)
        ..lineTo(width * .75, height * .24)
        ..close();
      canvas.drawPath(
        nick,
        Paint()
          ..color = Color.fromRGBO(48, 35, 28, veteranBlend * .36)
          ..style = PaintingStyle.fill,
      );
    }
  }
}
