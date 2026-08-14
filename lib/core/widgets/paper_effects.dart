import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Paper-craft depth cues for the folded-paper design system.
///
/// Instead of a diffuse Material elevation blur — or stacked semi-transparent
/// "sheets" (which read as dirty duplicate edges, especially on the dark
/// night-sky backdrop) — a lifted sheet gets exactly two cues:
///
///  1. a crisp, zero-blur strip in the sheet's own folded-edge colour directly
///     beneath it (the paper's thickness), and
///  2. a single soft ambient shadow grounding it on the table.
class PaperShadows {
  PaperShadows._();

  /// The standard shadow stack used by [PaperCard].
  ///
  /// [color] tints the soft ambient shadow (defaults to ink). When
  /// [edgeColor] is provided, a crisp folded-paper edge strip is drawn
  /// underneath the card first — this is what communicates card thickness,
  /// matching the chunky hard edge [PaperButton] uses.
  static List<BoxShadow> stack({
    Color? color,
    double elevation = 1.0,
    double radius = 18,
    Color? edgeColor,
  }) {
    final base = color ?? AppColors.paperInk;
    final e = elevation.clamp(0.5, 3.0);
    // Thickness of the visible folded edge grows gently with elevation.
    final edgeHeight = 3.0 + e * 1.5;
    return [
      if (edgeColor != null)
        // Crisp folded-under paper edge — zero blur so it reads as the
        // thickness of the sheet, not a blurry duplicate of the card.
        BoxShadow(
          color: edgeColor,
          offset: Offset(0, edgeHeight),
          blurRadius: 0,
        ),
      // A single soft ambient shadow grounding the sheet.
      BoxShadow(
        color: base.withOpacity(0.22),
        offset: Offset(0, edgeHeight + 2 + e),
        blurRadius: 7 + 3 * e,
        spreadRadius: -(1.5 + e),
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

  /// Chunky folded-edge shadow for buttons and medallions.
  static List<BoxShadow> buttonEdge(
    Color baseColor, {
    bool pressed = false,
    double dy = 4,
  }) {
    final edge = HSLColor.fromColor(baseColor)
        .withLightness(
            (HSLColor.fromColor(baseColor).lightness - 0.22).clamp(0.0, 1.0))
        .toColor();
    return [
      BoxShadow(
        color: edge,
        offset: Offset(0, pressed ? 1 : dy),
        blurRadius: 0,
      ),
      if (!pressed)
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          offset: Offset(0, dy + 2),
          blurRadius: 6,
          spreadRadius: -2,
        ),
    ];
  }

  /// Soft coloured glow for active nav items and currency badges.
  static List<BoxShadow> accentGlow(
    Color accent, {
    double intensity = 0.35,
    double blur = 10,
  }) =>
      [
        BoxShadow(
          color: accent.withOpacity(intensity),
          blurRadius: blur,
          spreadRadius: -2,
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
