import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/enums/game_enums.dart';

/// Bespoke artwork for every power-up.
///
/// Each power-up is drawn as *the object it actually is* — the Magnet is a
/// red-and-steel horseshoe magnet, the Shield is a heater shield, Slow-Mo is a
/// stopwatch — instead of a generic container with a small glyph stamped on it.
/// A pickup should be identifiable from its silhouette alone, at speed, without
/// reading anything.
///
/// The same painter backs the world pickup and the HUD chip, so what the player
/// grabs in the sky is exactly what they then see on their status bar.
///
/// Every routine draws centred on the canvas origin and scales off a single
/// radius [r], so the identical art works at 38 px in the world and 20 px in
/// the HUD. Callers own translation/rotation.
class PowerUpArt {
  const PowerUpArt._();

  /// Bright signature tint — auras, glows, HUD chip backgrounds.
  static Color auraColor(PowerUpType type) => type.visualColor;

  /// Deep tone used behind the emblem for contrast against a bright sky.
  static Color deepColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return const Color(0xFF1565C0);
      case PowerUpType.magnet:
        return const Color(0xFF6A1B9A);
      case PowerUpType.ghost:
        return const Color(0xFF00838F);
      case PowerUpType.slowMo:
        return const Color(0xFF00695C);
      case PowerUpType.coinRush:
        return const Color(0xFFC77800);
      case PowerUpType.doubleScore:
        return const Color(0xFFE64A19);
      case PowerUpType.shrink:
        return const Color(0xFF7B1FA2);
      case PowerUpType.blackHole:
        return const Color(0xFF311B92);
      case PowerUpType.giant:
        return const Color(0xFFE65100);
    }
  }

  // ── Shared glyphs (laid out once for the whole pool) ──────────────────────

  static final TextPainter _twoXGlyph = TextPainter(
    text: const TextSpan(
      text: '2X',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static final TextPainter _coinGlyph = TextPainter(
    text: const TextSpan(
      text: '\$',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Color(0xFF8D6E00),
        height: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Draws the pickup's halo — a soft bloom plus a slowly rotating dotted ring.
  /// Shared by every type so pickups still read as one family of collectibles
  /// even though each emblem is unique.
  static void drawHalo(
    Canvas canvas,
    PowerUpType type,
    double r,
    double phase, {
    double intensity = 1.0,
  }) {
    final tint = auraColor(type);
    final pulse = math.sin(phase * 3.0) * 0.5 + 0.5;

    canvas.drawCircle(
      Offset.zero,
      r * 1.55,
      Paint()
        ..color = tint.withOpacity((0.22 + pulse * 0.20) * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Dark backing disc: keeps pale emblems (steel shield, white ghost)
    // readable against a bright sky.
    canvas.drawCircle(
      Offset.zero,
      r * 1.06,
      Paint()..color = deepColor(type).withOpacity(0.30 * intensity),
    );

    final ringPaint = Paint()
      ..color = tint.withOpacity(0.85 * intensity)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final a = phase * 0.9 + i * math.pi / 4;
      final dotR = r * (0.10 + 0.05 * math.sin(phase * 4 + i));
      canvas.drawCircle(
        Offset(math.cos(a) * r * 1.28, math.sin(a) * r * 1.28),
        dotR,
        ringPaint,
      );
    }
  }

  /// Draws the power-up's emblem centred on the origin.
  static void draw(Canvas canvas, PowerUpType type, double r, double phase) {
    switch (type) {
      case PowerUpType.shield:
        _shield(canvas, r, phase);
      case PowerUpType.magnet:
        _magnet(canvas, r, phase);
      case PowerUpType.ghost:
        _ghost(canvas, r, phase);
      case PowerUpType.slowMo:
        _stopwatch(canvas, r, phase);
      case PowerUpType.coinRush:
        _coinStack(canvas, r, phase);
      case PowerUpType.doubleScore:
        _doubleScore(canvas, r, phase);
      case PowerUpType.shrink:
        _shrink(canvas, r, phase);
      case PowerUpType.blackHole:
        _blackHole(canvas, r, phase);
      case PowerUpType.giant:
        _giant(canvas, r, phase);
    }
  }

  // ── Shield — a heater shield with a steel face and a bright chevron ───────

  static void _shield(Canvas canvas, double r, double phase) {
    final w = r * 0.90;
    final h = r * 1.05;

    final body = Path()
      ..moveTo(0, -h)
      ..lineTo(w, -h * 0.62)
      ..cubicTo(w, h * 0.10, w * 0.62, h * 0.70, 0, h)
      ..cubicTo(-w * 0.62, h * 0.70, -w, h * 0.10, -w, -h * 0.62)
      ..close();

    // Polished steel face.
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF4FF),
            Color(0xFF90CAF9),
            Color(0xFF1E6FBF),
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2),
        ),
    );

    // Bright chevron crest.
    final crest = Path()
      ..moveTo(0, -h * 0.42)
      ..lineTo(w * 0.52, -h * 0.02)
      ..lineTo(w * 0.52, h * 0.16)
      ..lineTo(0, -h * 0.24)
      ..lineTo(-w * 0.52, h * 0.16)
      ..lineTo(-w * 0.52, -h * 0.02)
      ..close();
    canvas.drawPath(crest, Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.92));

    // Rim + rivets.
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF0D47A1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.11,
    );
    final rivet = Paint()..color = const Color(0xFFE3F2FD);
    canvas.drawCircle(Offset(-w * 0.58, -h * 0.48), r * 0.07, rivet);
    canvas.drawCircle(Offset(w * 0.58, -h * 0.48), r * 0.07, rivet);

    // Moving specular sweep, so the shield reads as metal.
    final sweep = math.sin(phase * 1.6) * w * 0.5;
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(sweep, -h * 0.15),
        width: w * 0.30,
        height: h * 2.4,
      ),
      Paint()..color = Colors.white.withOpacity(0.20),
    );
    canvas.restore();
  }

  // ── Magnet — a red horseshoe magnet with polished steel poles ─────────────

  static void _magnet(Canvas canvas, double r, double phase) {
    final outer = r * 0.88;
    final inner = r * 0.42;
    final legY = r * 0.62;

    final body = Path()
      ..moveTo(-outer, legY)
      ..lineTo(-outer, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: outer),
          math.pi, math.pi, false)
      ..lineTo(outer, legY)
      ..lineTo(inner, legY)
      ..lineTo(inner, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: inner),
          0, -math.pi, false)
      ..lineTo(-inner, legY)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7A6B), Color(0xFFD32F2F), Color(0xFF8E1414)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromCenter(
              center: Offset.zero, width: outer * 2, height: outer * 2),
        ),
    );

    // Steel pole tips, clipped to the horseshoe so they sit flush.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTRB(-outer * 1.1, legY - r * 0.34, outer * 1.1, legY + r * 0.1),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F7FA), Color(0xFF9AA7B4)],
        ).createShader(
          Rect.fromLTRB(-outer, legY - r * 0.34, outer, legY + r * 0.1),
        ),
    );
    // Gloss along the top of the arc.
    canvas.drawCircle(
      Offset(-outer * 0.30, -outer * 0.52),
      r * 0.16,
      Paint()..color = Colors.white.withOpacity(0.55),
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF5D0F0F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    // Attraction arcs snapping between the poles.
    final spark = Paint()
      ..color = const Color(0xFFFFF59D)
          .withOpacity(0.45 + 0.45 * math.sin(phase * 6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;
    final mid = (outer + inner) / 2;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(0, legY + r * 0.18), width: mid * 2, height: r * 0.5),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      spark,
    );
  }

  // ── Ghost — a floating sheet ghost with a wavy hem ────────────────────────

  static void _ghost(Canvas canvas, double r, double phase) {
    final w = r * 0.80;
    final h = r * 0.98;
    final drift = math.sin(phase * 2.2) * r * 0.06;

    canvas.save();
    canvas.translate(0, drift);

    final body = Path()..moveTo(-w, h * 0.45);
    body.lineTo(-w, -h * 0.15);
    body.arcToPoint(Offset(w, -h * 0.15),
        radius: Radius.circular(w), clockwise: true);
    body.lineTo(w, h * 0.45);
    // Wavy hem.
    for (int i = 0; i < 3; i++) {
      final x0 = w - (i * 2 * w / 3);
      final x1 = w - ((i + 1) * 2 * w / 3);
      body.quadraticBezierTo(
        (x0 + x1) / 2,
        h * (i.isEven ? 1.0 : 0.05),
        x1,
        h * 0.45,
      );
    }
    body.close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.97),
            const Color(0xFFB2EBF2).withOpacity(0.82),
          ],
        ).createShader(
          Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2),
        ),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF00838F).withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08,
    );

    // Face.
    final eye = Paint()..color = const Color(0xFF00363A);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-w * 0.36, -h * 0.22),
          width: r * 0.22,
          height: r * 0.30),
      eye,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.36, -h * 0.22),
          width: r * 0.22,
          height: r * 0.30),
      eye,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, h * 0.12), width: r * 0.26, height: r * 0.20),
      eye..color = const Color(0xFF00363A).withOpacity(0.75),
    );

    canvas.restore();
  }

  // ── Slow-Mo — a pocket stopwatch ──────────────────────────────────────────

  static void _stopwatch(Canvas canvas, double r, double phase) {
    final bodyR = r * 0.82;

    // Crown + side buttons.
    final metal = Paint()..color = const Color(0xFF455A64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, -bodyR - r * 0.16),
            width: r * 0.34,
            height: r * 0.28),
        Radius.circular(r * 0.08),
      ),
      metal,
    );
    canvas.save();
    canvas.rotate(-0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, -bodyR - r * 0.10),
            width: r * 0.22,
            height: r * 0.22),
        Radius.circular(r * 0.06),
      ),
      metal,
    );
    canvas.restore();

    // Case + face.
    canvas.drawCircle(Offset.zero, bodyR, Paint()..color = const Color(0xFF37474F));
    canvas.drawCircle(
      Offset.zero,
      bodyR * 0.86,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFCFD8DC)],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: bodyR * 0.86),
        ),
    );

    // Hour ticks.
    final tick = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final long = i % 3 == 0;
      canvas.drawLine(
        Offset(math.cos(a) * bodyR * (long ? 0.60 : 0.68),
            math.sin(a) * bodyR * (long ? 0.60 : 0.68)),
        Offset(math.cos(a) * bodyR * 0.76, math.sin(a) * bodyR * 0.76),
        tick,
      );
    }

    // Hands — the sweep hand crawls, selling "time slowed".
    final hand = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(0, -bodyR * 0.46), hand);
    canvas.drawLine(
      Offset.zero,
      Offset(math.cos(-0.4) * bodyR * 0.34, math.sin(-0.4) * bodyR * 0.34),
      hand,
    );
    final sweep = phase * 0.55;
    canvas.drawLine(
      Offset.zero,
      Offset(math.cos(sweep - math.pi / 2) * bodyR * 0.62,
          math.sin(sweep - math.pi / 2) * bodyR * 0.62),
      Paint()
        ..color = const Color(0xFF00BFA5)
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset.zero, r * 0.09, Paint()..color = const Color(0xFF00BFA5));

    // Glass glare.
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: bodyR * 0.86)));
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-bodyR * 0.34, -bodyR * 0.44),
          width: bodyR * 0.9,
          height: bodyR * 0.42),
      Paint()..color = Colors.white.withOpacity(0.42),
    );
    canvas.restore();
  }

  // ── Coin Rush — a stack of gold coins ─────────────────────────────────────

  static void _coinStack(Canvas canvas, double r, double phase) {
    final coinR = r * 0.62;
    final thickness = r * 0.22;

    void coin(double dy, double scale) {
      final rect = Rect.fromCenter(
        center: Offset(0, dy),
        width: coinR * 2 * scale,
        height: coinR * 1.15 * scale,
      );
      // Edge.
      canvas.drawOval(
        rect.translate(0, thickness * 0.5),
        Paint()..color = const Color(0xFFB8860B),
      );
      // Face.
      canvas.drawOval(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8B0), Color(0xFFFFC107), Color(0xFFE08E00)],
          ).createShader(rect),
      );
      canvas.drawOval(
        rect.deflate(coinR * 0.16 * scale),
        Paint()
          ..color = const Color(0xFFB8860B).withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06,
      );
    }

    coin(r * 0.52, 0.88);
    coin(r * 0.16, 0.94);
    coin(-r * 0.22, 1.0);

    _coinGlyph.paint(
      canvas,
      Offset(-_coinGlyph.width / 2, -r * 0.22 - _coinGlyph.height / 2),
    );

    // Sparkles rising off the stack.
    for (int i = 0; i < 3; i++) {
      final t = (phase * 1.4 + i * 0.33) % 1.0;
      final a = -math.pi / 2 + (i - 1) * 0.8;
      final d = r * (0.9 + t * 0.9);
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d),
        r * 0.10 * (1 - t),
        Paint()..color = const Color(0xFFFFF59D).withOpacity(1 - t),
      );
    }
  }

  // ── Double Score — a starburst badge reading 2X ───────────────────────────

  static void _doubleScore(Canvas canvas, double r, double phase) {
    // Rotating rays.
    canvas.save();
    canvas.rotate(phase * 0.8);
    final ray = Paint()..color = const Color(0xFFFFAB91).withOpacity(0.75);
    for (int i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawPath(
        Path()
          ..moveTo(-r * 0.13, -r * 0.55)
          ..lineTo(0, -r * 1.18)
          ..lineTo(r * 0.13, -r * 0.55)
          ..close(),
        ray,
      );
      canvas.restore();
    }
    canvas.restore();

    // Badge.
    canvas.drawCircle(
      Offset.zero,
      r * 0.74,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFF8A65), Color(0xFFD84315)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.74)),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.74,
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    final s = (r * 0.74 * 2) / 26.0;
    canvas.save();
    canvas.scale(s);
    _twoXGlyph.paint(
      canvas,
      Offset(-_twoXGlyph.width / 2, -_twoXGlyph.height / 2),
    );
    canvas.restore();
  }

  // ── Shrink — a plane compressed by inward arrows ──────────────────────────

  static void _shrink(Canvas canvas, double r, double phase) {
    final squeeze = (math.sin(phase * 3.0) * 0.5 + 0.5) * r * 0.14;

    // Ghosted "before" outline.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 1.7),
        Radius.circular(r * 0.16),
      ),
      Paint()
        ..color = const Color(0xFFE1BEE7).withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07,
    );

    // Four inward arrows.
    final arrow = Paint()
      ..color = const Color(0xFFF3E5F5)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      final tip = r * 0.40 + squeeze;
      final tail = r * 0.92 + squeeze;
      canvas.drawPath(
        Path()
          ..moveTo(0, -tip)
          ..lineTo(-r * 0.22, -tip - r * 0.24)
          ..lineTo(-r * 0.08, -tip - r * 0.24)
          ..lineTo(-r * 0.08, -tail)
          ..lineTo(r * 0.08, -tail)
          ..lineTo(r * 0.08, -tip - r * 0.24)
          ..lineTo(r * 0.22, -tip - r * 0.24)
          ..close(),
        arrow,
      );
      canvas.restore();
    }

    // The tiny compressed plane at the core.
    final ps = r * 0.30 - squeeze * 0.4;
    canvas.drawPath(
      Path()
        ..moveTo(0, -ps)
        ..lineTo(ps * 0.82, ps * 0.85)
        ..lineTo(0, ps * 0.42)
        ..lineTo(-ps * 0.82, ps * 0.85)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  // ── Black Hole — an accretion disc around a dark core ─────────────────────

  static void _blackHole(Canvas canvas, double r, double phase) {
    // Warped accretion disc.
    for (int i = 3; i >= 1; i--) {
      final rr = r * (0.42 + i * 0.20);
      canvas.save();
      canvas.rotate(phase * (0.6 + i * 0.35));
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: rr * 2, height: rr * 1.15),
        0,
        math.pi * 1.55,
        false,
        Paint()
          ..shader = SweepGradient(
            colors: [
              const Color(0xFFB388FF).withOpacity(0.15),
              const Color(0xFF7C4DFF).withOpacity(0.95),
              const Color(0xFFE1BEE7).withOpacity(0.20),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: rr),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.13
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // Event horizon.
    canvas.drawCircle(
      Offset.zero,
      r * 0.40,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF000000), Color(0xFF1A0033)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.40)),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.40,
      Paint()
        ..color = const Color(0xFFD1C4E9).withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06,
    );
  }

  // ── Giant Mode — a small plane dwarfed by a huge one, with impact marks ───

  static void _giant(Canvas canvas, double r, double phase) {
    final grow = math.sin(phase * 2.4) * 0.5 + 0.5;

    // Outward "growing" pulse rings.
    canvas.drawCircle(
      Offset.zero,
      r * (0.80 + grow * 0.34),
      Paint()
        ..color = const Color(0xFFFFD54F).withOpacity(0.55 * (1 - grow))
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10,
    );

    // The big plane.
    final big = r * 0.92;
    final bigPath = Path()
      ..moveTo(0, -big)
      ..lineTo(big * 0.86, big * 0.80)
      ..lineTo(0, big * 0.40)
      ..lineTo(-big * 0.86, big * 0.80)
      ..close();
    canvas.drawPath(
      bigPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3E0), Color(0xFFFFB300), Color(0xFFE65100)],
        ).createShader(
          Rect.fromCenter(center: Offset.zero, width: big * 2, height: big * 2),
        ),
    );
    canvas.drawPath(
      bigPath,
      Paint()
        ..color = const Color(0xFF8C3B00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );
    // Centre crease.
    canvas.drawLine(
      Offset(0, -big),
      Offset(0, big * 0.40),
      Paint()
        ..color = const Color(0xFF8C3B00).withOpacity(.7)
        ..strokeWidth = r * 0.06,
    );

    // A tiny ghosted plane for scale — the whole point is "you are bigger".
    final small = r * 0.26;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.74, -r * 0.52 - small)
        ..lineTo(-r * 0.74 + small * 0.8, -r * 0.52 + small * 0.75)
        ..lineTo(-r * 0.74, -r * 0.52 + small * 0.36)
        ..lineTo(-r * 0.74 - small * 0.8, -r * 0.52 + small * 0.75)
        ..close(),
      Paint()..color = Colors.white.withOpacity(.55),
    );

    // Impact sparks flying off the leading edge.
    final spark = Paint()..color = const Color(0xFFFFF176);
    for (int i = 0; i < 4; i++) {
      final t = (phase * 1.8 + i * 0.25) % 1.0;
      final a = -math.pi / 2 + (i - 1.5) * 0.55;
      final d = r * (0.9 + t * 0.8);
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d),
        r * 0.11 * (1 - t),
        spark..color = const Color(0xFFFFF176).withOpacity(1 - t),
      );
    }
  }
}
