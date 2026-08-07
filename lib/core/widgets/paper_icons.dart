import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Identifiers for the custom paper-craft icons.
///
/// Replaces the emoji / unicode symbols (✈️ 🍃 🎯 🗓️ ● ◆) used throughout the
/// app with hand-painted vector icons that share a single origami language:
/// bold filled shapes, a darker "folded-under" edge offset, and a single light
/// specular highlight.
enum PaperIconData {
  coin,
  gem,
  glider,
  leaf,
  bullseye,
  calendar,
}

/// A paper-craft vector icon, painted with [CustomPainter] (no assets/deps).
///
/// Each icon is drawn in two passes:
///  1. a darker "fold" offset down-right that reads as the underside of a
///     stacked paper cut-out, and
///  2. the main coloured face plus a single specular highlight.
class PaperIcon extends StatelessWidget {
  const PaperIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.accentColor,
  });

  final PaperIconData icon;
  final double size;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PaperIconPainter(icon, color, accentColor),
        ),
      ),
    );
  }
}

class _PaperIconPainter extends CustomPainter {
  _PaperIconPainter(this.icon, this.color, this.accentColor);

  final PaperIconData icon;
  final Color? color;
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    switch (icon) {
      case PaperIconData.coin:
        _paintCoin(canvas, size);
        break;
      case PaperIconData.gem:
        _paintGem(canvas, size);
        break;
      case PaperIconData.glider:
        _paintGlider(canvas, size);
        break;
      case PaperIconData.leaf:
        _paintLeaf(canvas, size);
        break;
      case PaperIconData.bullseye:
        _paintBullseye(canvas, size);
        break;
      case PaperIconData.calendar:
        _paintCalendar(canvas, size);
        break;
    }
  }

  // ── Coin ─────────────────────────────────────────────────────────────────
  void _paintCoin(Canvas canvas, Size size) {
    final gold = color ?? const Color(0xFFFFC83D);
    final deep = _darken(gold, 0.28);
    final hi = const Color(0xFFFFF1B0);
    final r = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // outer folded edge
    canvas.drawCircle(
      center.translate(r * 0.07, r * 0.09),
      r * 0.92,
      Paint()..color = deep,
    );
    // face
    final face = Paint()
      ..shader = RadialGradient(
        colors: [_lighten(gold, 0.12), gold, deep],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r * 0.9, face);

    // inner ring (paper cut)
    canvas.drawCircle(
      center,
      r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = deep.withOpacity(0.55),
    );
    // star/fold emblem
    final starR = r * 0.3;
    final path = _star(center, starR, starR * 0.42, 5);
    canvas.drawPath(
      path,
      Paint()..color = _darken(gold, 0.18).withOpacity(0.85),
    );
    canvas.drawPath(
      path.shift(Offset(-r * 0.02, -r * 0.02)),
      Paint()..color = _lighten(gold, 0.25).withOpacity(0.7),
    );
    // specular
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-r * 0.32, -r * 0.36),
        width: r * 0.5,
        height: r * 0.28,
      ),
      Paint()..color = hi.withOpacity(0.6),
    );
  }

  // ── Gem ──────────────────────────────────────────────────────────────────
  void _paintGem(Canvas canvas, Size size) {
    final gem = color ?? const Color(0xFF54C8EC);
    final deep = _darken(gem, 0.35);
    final hi = const Color(0xFFD6F4FF);
    final w = size.width;
    final h = size.height;

    final face = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.92, h * 0.38)
      ..lineTo(w * 0.5, h * 0.94)
      ..lineTo(w * 0.08, h * 0.38)
      ..close();

    // folded underside
    canvas.drawPath(
      face.shift(Offset(w * 0.05, h * 0.06)),
      Paint()..color = deep,
    );
    // face
    canvas.drawPath(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(gem, 0.2), gem, deep],
        ).createShader(Offset.zero & size),
    );
    // facet lines
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = deep.withOpacity(0.55)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.08, h * 0.38)
        ..lineTo(w * 0.92, h * 0.38)
        ..moveTo(w * 0.5, h * 0.08)
        ..lineTo(w * 0.5, h * 0.94)
        ..moveTo(w * 0.5, h * 0.38)
        ..lineTo(w * 0.5, h * 0.38),
      facet,
    );
    // top highlight facet
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.08)
        ..lineTo(w * 0.22, h * 0.38)
        ..lineTo(w * 0.5, h * 0.38)
        ..close(),
      Paint()..color = hi.withOpacity(0.55),
    );
    // specular dot
    canvas.drawCircle(
      Offset(w * 0.34, h * 0.26),
      w * 0.06,
      Paint()..color = hi.withOpacity(0.9),
    );
  }

  // ── Origami glider (Classic) ─────────────────────────────────────────────
  void _paintGlider(Canvas canvas, Size size) {
    final c = color ?? const Color(0xFFF5A623);
    final deep = _darken(c, 0.3);
    final w = size.width;
    final h = size.height;
    final plane = Path()
      ..moveTo(w * 0.86, h * 0.5)
      ..lineTo(w * 0.12, h * 0.18)
      ..lineTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.12, h * 0.82)
      ..close();
    final fold = Path()
      ..moveTo(w * 0.86, h * 0.5)
      ..lineTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.12, h * 0.82)
      ..close();

    canvas.drawPath(plane.shift(Offset(w * 0.04, h * 0.05)),
        Paint()..color = _darken(c, 0.45));
    canvas.drawPath(plane, Paint()..color = c);
    // folded underside triangle
    canvas.drawPath(fold, Paint()..color = deep);
    // crease line
    canvas.drawLine(
      Offset(w * 0.3, h * 0.5),
      Offset(w * 0.86, h * 0.5),
      Paint()
        ..color = _lighten(c, 0.2).withOpacity(0.7)
        ..strokeWidth = w * 0.02,
    );
  }

  // ── Leaf (Zen) ───────────────────────────────────────────────────────────
  void _paintLeaf(Canvas canvas, Size size) {
    final c = color ?? const Color(0xFF56CF87);
    final deep = _darken(c, 0.32);
    final w = size.width;
    final h = size.height;

    final leaf = Path()
      ..moveTo(w * 0.18, h * 0.78)
      ..quadraticBezierTo(w * 0.1, h * 0.3, w * 0.6, h * 0.14)
      ..quadraticBezierTo(w * 0.9, h * 0.3, w * 0.82, h * 0.72)
      ..quadraticBezierTo(w * 0.55, h * 0.86, w * 0.18, h * 0.78)
      ..close();

    canvas.drawPath(leaf.shift(Offset(w * 0.05, h * 0.06)),
        Paint()..color = _darken(c, 0.45));
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_lighten(c, 0.18), c, deep],
        ).createShader(Offset.zero & size),
    );
    // midrib
    canvas.drawLine(
      Offset(w * 0.22, h * 0.74),
      Offset(w * 0.72, h * 0.26),
      Paint()
        ..color = deep.withOpacity(0.8)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );
    // side veins
    final vein = Paint()
      ..color = deep.withOpacity(0.55)
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    for (final t in [0.35, 0.5, 0.65]) {
      final p = Offset(w * (0.22 + 0.5 * t), h * (0.74 - 0.48 * t));
      canvas.drawLine(p, p.translate(w * 0.16, h * 0.05), vein);
      canvas.drawLine(p, p.translate(w * 0.05, -h * 0.16), vein);
    }
  }

  // ── Bullseye / hoop (Trials) ─────────────────────────────────────────────
  void _paintBullseye(Canvas canvas, Size size) {
    final c = color ?? const Color(0xFFFF6B6B);
    final deep = _darken(c, 0.35);
    final cream = const Color(0xFFFCF7EA);
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // outer folded ring
    canvas.drawCircle(center.translate(r * 0.07, r * 0.09), r * 0.9,
        Paint()..color = _darken(c, 0.45));
    // rings (outer -> inner): red, cream, red, cream bull
    canvas.drawCircle(center, r * 0.9, Paint()..color = c);
    canvas.drawCircle(center, r * 0.68, Paint()..color = cream);
    canvas.drawCircle(center, r * 0.46, Paint()..color = c);
    canvas.drawCircle(center, r * 0.24, Paint()..color = cream);
    canvas.drawCircle(center, r * 0.12, Paint()..color = deep);

    // small paper-fold arrow nock at top-left
    final arrow = Path()
      ..moveTo(r * 0.25, r * 0.4)
      ..lineTo(r * 0.5, r * 0.6)
      ..lineTo(r * 0.3, r * 0.55)
      ..close();
    canvas.drawPath(arrow, Paint()..color = deep.withOpacity(0.5));
  }

  // ── Calendar stamp (Daily) ───────────────────────────────────────────────
  void _paintCalendar(Canvas canvas, Size size) {
    final c = color ?? const Color(0xFF4FC3F7);
    final deep = _darken(c, 0.32);
    final w = size.width;
    final h = size.height;
    final pad = w * 0.12;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, h * 0.16, w - 2 * pad, h * 0.72),
      Radius.circular(w * 0.12),
    );

    // folded underside
    canvas.drawRRect(
      rect.shift(Offset(w * 0.05, h * 0.06)),
      Paint()..color = _darken(c, 0.45),
    );
    // page
    canvas.drawRRect(rect, Paint()..color = c);
    // header band
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(pad, h * 0.16, w - 2 * pad, h * 0.26),
        topLeft: Radius.circular(w * 0.12),
        topRight: Radius.circular(w * 0.12),
      ),
      Paint()..color = deep,
    );
    // binding rings
    final ring = Paint()
      ..color = const Color(0xFFFCF7EA)
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.32, h * 0.16), Offset(w * 0.32, h * 0.28), ring);
    canvas.drawLine(
        Offset(w * 0.68, h * 0.16), Offset(w * 0.68, h * 0.28), ring);

    // a little paper-plane "date" glyph
    final plane = Path()
      ..moveTo(w * 0.7, h * 0.62)
      ..lineTo(w * 0.34, h * 0.5)
      ..lineTo(w * 0.44, h * 0.62)
      ..lineTo(w * 0.34, h * 0.74)
      ..close();
    canvas.drawPath(plane, Paint()..color = deep.withOpacity(0.85));
    // specular
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.34, h * 0.3),
        width: w * 0.3,
        height: h * 0.1,
      ),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  Path _star(Offset c, double outer, double inner, int points) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / points;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  Color _darken(Color c, double amount) =>
      HSLColor.fromColor(c).withLightness(
        (HSLColor.fromColor(c).lightness - amount).clamp(0.0, 1.0),
      ).toColor();

  Color _lighten(Color c, double amount) =>
      HSLColor.fromColor(c).withLightness(
        (HSLColor.fromColor(c).lightness + amount).clamp(0.0, 1.0),
      ).toColor();

  @override
  bool shouldRepaint(covariant _PaperIconPainter old) =>
      old.icon != icon || old.color != color || old.accentColor != accentColor;
}
