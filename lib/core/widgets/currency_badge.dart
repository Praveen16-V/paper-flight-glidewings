import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'currency_chip.dart';
import 'paper_card.dart';
import 'paper_effects.dart';

/// Compact paper sheet wrapper for currency chips in screen headers.
///
/// Replaces the glassmorphic badge on the main menu so currency display reads
/// as a folded paper strip everywhere (menu, hangar, shop).
class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge({
    super.key,
    required this.child,
    this.glowColor,
  });

  final Widget child;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          if (glowColor != null)
            ...PaperShadows.accentGlow(glowColor!, intensity: 0.18),
        ],
      ),
      child: PaperCard(
        color: AppColors.paperBright,
        radius: AppRadius.pill,
        elevation: 0.5,
        textureOpacity: 0.35,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: child,
      ),
    );
  }
}

/// Standard coin + gem badge pair for screen headers.
class CurrencyBadgeRow extends StatelessWidget {
  const CurrencyBadgeRow({
    super.key,
    required this.coins,
    required this.gems,
    this.coinIconSize = 16,
    this.coinFontSize = 14,
    this.gemIconSize = 14,
    this.gemFontSize = 13,
    this.spacing = 8,
  });

  final int coins;
  final int gems;
  final double coinIconSize;
  final double coinFontSize;
  final double gemIconSize;
  final double gemFontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CurrencyBadge(
          glowColor: AppColors.coinGold,
          child: CoinChip(
            coins,
            iconSize: coinIconSize,
            fontSize: coinFontSize,
            color: AppColors.coinGoldDeep,
          ),
        ),
        SizedBox(width: spacing),
        CurrencyBadge(
          glowColor: AppColors.gemBlue,
          child: GemChip(
            gems,
            iconSize: gemIconSize,
            fontSize: gemFontSize,
            color: AppColors.gemBlueDeep,
          ),
        ),
      ],
    );
  }
}
