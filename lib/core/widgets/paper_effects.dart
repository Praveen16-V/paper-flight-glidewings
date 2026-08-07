import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Sharp, slightly-offset "cut-paper" shadows stacked beneath a sheet.
///
/// Instead of a single heavy Gaussian blur (which reads as Material elevation),
/// these are tight, low-blur offsets that look like stacked sheets of coloured
/// paper peeking out from under the top card.
class PaperShadows {
  PaperShadows._();

  /// The standard layered stack used by [PaperCard].
  static List<BoxShadow> stack({
    Color? color,
    double elevation = 1.0,
    double radius = 18,
  }) {
    final base = color ?? AppColors.paperInk;
    final e = elevation.clamp(0.5, 3.0);
    return [
      // darkest bottom sheet, furthest offset
      BoxShadow(
        color: base.withOpacity(0.10 * e + 0.05),
        offset: Offset(0, 6 * e),
        blurRadius: 1.5,
        spreadRadius: 0,
      ),
      // mid sheet
      BoxShadow(
        color: base.withOpacity(0.10 * e + 0.04),
        offset: Offset(0, 3 * e),
        blurRadius: 1.0,
      ),
      // contact shadow
      BoxShadow(
        color: Colors.black.withOpacity(0.18 + 0.06 * e),
        offset: Offset(0, 1.5 * e),
        blurRadius: 4 * e,
        spreadRadius: -1,
      ),
    ];
  }

  /// A single hard paper edge for dog-ears / ribbons.
  static List<BoxShadow> edge(Color c, {double dy = 2}) => [
        BoxShadow(
          color: Colors.black.withOpacity(0.22),
          offset: Offset(0, dy),
          blurRadius: 0,
        ),
        BoxShadow(
          color: c.withOpacity(0.5),
          offset: Offset(0, dy + 1.5),
          blurRadius: 0,
        ),
      ];
}

/// A low-opacity paper-grain / crease overlay.
///
/// Drawn procedurally so there is no raster asset: it layers a faint fibre
/// noise and two soft diagonal creases. Drop it inside a clip (it's painted
/// with [BlendMode.multiply] over cream paper so it stays invisible on dark).
class PaperTexture extends StatelessWidget {
  const PaperTexture({
    super.key,
    this.opacity = 0.5,
    this.crease = true,
  });

  final double opacity;
  final bool crease;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _PaperTexturePainter(opacity, crease),
        ),
      ),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  _PaperTexturePainter(this.opacity, this.crease);
  final double opacity;
  final bool crease;

  static final math.Random _rng = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    // Fibre speckle — tiny warm & cool dots.
    final speckWarm = Paint()..color = const Color(0x14000000);
    final speckCool = Paint()..color = const Color(0x14FFFFFF);
    final count = (size.width * size.height / 900).clamp(40, 260).toInt();
    for (var i = 0; i < count; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height;
      canvas.drawCircle(
        Offset(x, y),
        _rng.nextDouble() * 0.7 + 0.2,
        _rng.nextBool() ? speckWarm : speckCool,
      );
    }

    if (!crease) return;
    // Two soft diagonal creases.
    final creasePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.05 * opacity),
          const Color(0x12000000),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 0.52, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, creasePaint);
  }

  @override
  bool shouldRepaint(_PaperTexturePainter old) =>
      old.opacity != opacity || old.crease != crease;
}
