import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'paper_icons.dart';

/// A compact gold-coin chip used to show coin amounts.
///
/// Replaces the old `'●'` Unicode glyph + Text combination with a crisp
/// custom-painted gold coin (with a specular highlight) next to a tabular
/// monospaced amount so digits never jitter.
class CoinChip extends StatelessWidget {
  const CoinChip(
    this.amount, {
    super.key,
    this.iconSize = 16,
    this.fontSize = 13,
    this.color = AppColors.coinGold,
    this.style,
    this.spacing = 5,
  });

  final int amount;
  final double iconSize;
  final double fontSize;
  final Color color;
  final TextStyle? style;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaperIcon(PaperIconData.coin, size: iconSize, color: color),
        SizedBox(width: spacing),
        Text(
          '$amount',
          style: style ??
              TextStyle(
                fontFamily: AppTypography.mono,
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

/// A compact blue-gem chip. Replaces the old `'◆'` glyph.
class GemChip extends StatelessWidget {
  const GemChip(
    this.amount, {
    super.key,
    this.iconSize = 15,
    this.fontSize = 12,
    this.color = AppColors.gemBlue,
    this.style,
    this.spacing = 5,
  });

  final int amount;
  final double iconSize;
  final double fontSize;
  final Color color;
  final TextStyle? style;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaperIcon(PaperIconData.gem, size: iconSize, color: color),
        SizedBox(width: spacing),
        Text(
          '$amount',
          style: style ??
              TextStyle(
                fontFamily: AppTypography.mono,
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}
