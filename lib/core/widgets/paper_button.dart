import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// A chunky paper-cut button.
///
/// A solid coloured sheet with a hard darker "folded edge" beneath it that
/// presses down on tap — a tactile origami button instead of a flat Material
/// raised button.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.textColor,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color? color;
  final Color? textColor;
  final bool expand;
  final bool compact;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accent;
    final enabled = widget.onPressed != null;
    final effective = enabled ? color : color.withOpacity(0.45);
    final edge = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness - 0.22)
            .clamp(0.0, 1.0))
        .toColor();
    final textColor = widget.textColor ?? AppColors.paperInk;

    final double height = widget.compact ? 40 : 52;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: height,
        width: widget.expand ? double.infinity : null,
        transform: Matrix4.translationValues(0, _pressed ? 5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: edge,
                    offset: Offset(0, _pressed ? 1 : 6),
                    blurRadius: 0,
                  ),
                  if (!_pressed)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 8),
                      blurRadius: 8,
                      spreadRadius: -3,
                    ),
                ]
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: effective,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 16 : 28),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                IconTheme(
                  data: IconThemeData(color: textColor, size: 20),
                  child: widget.icon!,
                ),
                SizedBox(width: widget.compact ? 6 : 10),
              ],
              Text(
                widget.label,
                style: AppTypography.label.copyWith(
                  color: textColor,
                  fontSize: widget.compact ? 13 : 17,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
