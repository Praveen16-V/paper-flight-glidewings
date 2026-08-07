import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'paper_effects.dart';

/// A sheet of folded paper — the core surface of the design system.
///
/// Renders a light cream/kraft card with layered cut-paper shadows, a subtle
/// paper-grain overlay, an optional darker folded edge, and rounded corners.
/// Used everywhere the old code used a flat `BoxDecoration` with
/// `BorderRadius.circular(18)`.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color,
    this.edgeColor,
    this.radius = 20,
    this.elevation = 1.0,
    this.textureOpacity = 0.55,
    this.onTap,
    this.borderColor,
    this.borderGradient,
    this.borderWidth = 1.4,
    this.gradient,
    this.dogEar,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? edgeColor;
  final double radius;
  final double elevation;
  final double textureOpacity;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Gradient? borderGradient;
  final double borderWidth;
  final Gradient? gradient;

  /// Optional folded-corner ribbon/badge drawn in the top-right corner.
  final DogEar? dogEar;

  @override
  Widget build(BuildContext context) {
    final paper = color ?? AppColors.paper;
    final edge = edgeColor ?? _foldedEdge(paper);
    final r = Radius.circular(radius);
    final borderRadius = BorderRadius.all(r);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: PaperShadows.stack(
                color: AppColors.paperInk,
                elevation: elevation,
                radius: radius,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Folded-under bottom edge strip (gives paper thickness).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: edge,
                      borderRadius: BorderRadius.only(
                        bottomLeft: r,
                        bottomRight: r,
                      ),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: paper,
                            gradient: gradient,
                          ),
                        ),
                      ),
                      PaperTexture(opacity: textureOpacity),
                      // top sheen
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.35),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: padding,
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: AppColors.paperInk,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
                if (borderColor != null && borderGradient == null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          border: Border.all(
                            color: borderColor!,
                            width: borderWidth,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (borderGradient != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GradientBorderPainter(
                          gradient: borderGradient!,
                          strokeWidth: borderWidth,
                          radius: radius,
                        ),
                      ),
                    ),
                  ),
                if (dogEar != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: dogEar!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _foldedEdge(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }
}

/// A folded paper-corner ribbon / dog-eared badge.
///
/// For tags like "NEW BEST!", "TODAY'S SEED", "RECOMMENDED". It draws a folded
/// triangular corner plus a small ribbon label.
class DogEar extends StatelessWidget {
  const DogEar({
    super.key,
    required this.label,
    this.color = AppColors.accent,
    this.textColor = AppColors.paperInk,
    this.size = 64,
  });

  final String label;
  final Color color;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Diagonal length of the folded triangle; the label runs along it.
    final diag = size * 0.78 * 1.4142;
    final fontSize = (size * 0.15).clamp(7.0, 11.0);

    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: _DogEarClipper(),
        child: Container(
          color: color,
          alignment: Alignment.topRight,
          child: Transform.translate(
            offset: Offset(-size * 0.14, size * 0.2),
            child: Transform.rotate(
              angle: 0.785398, // 45° — text runs down the diagonal
              alignment: Alignment.center,
              child: SizedBox(
                width: diag,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                    color: textColor,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DogEarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Triangle folded from top-right corner.
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.78)
      ..lineTo(size.width * 0.22, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.gradient,
    required this.strokeWidth,
    required this.radius,
  });

  final Gradient gradient;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

