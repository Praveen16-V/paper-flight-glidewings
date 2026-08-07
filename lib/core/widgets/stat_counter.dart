import 'package:flutter/material.dart';

import '../constants/app_typography.dart';

/// A numeric readout in the monospaced tabular face.
///
/// Use for score, distance, coins and any counter that ticks up at runtime —
/// tabular figures guarantee the digits never shift horizontally.
class StatCounter extends StatelessWidget {
  const StatCounter(
    this.value, {
    super.key,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  final num value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;

  /// Renders integers without a decimal, doubles with one decimal.
  String get _text {
    if (value is int) return value.toString();
    final d = value.toDouble();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppTypography.stat;
    return Text(
      '$prefix$_text$suffix',
      maxLines: maxLines,
      textAlign: textAlign,
      style: base.copyWith(
        fontFamily: AppTypography.mono,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
