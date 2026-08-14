import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../enums/game_enums.dart';
import 'paper_card.dart';
import 'paper_effects.dart';
import 'paper_icons.dart';

/// Visual identity for a game mode — accent, paper tint, and icon.
class ModePresentation {
  const ModePresentation({
    required this.mode,
    required this.nameKey,
    required this.icon,
    required this.accent,
    required this.paperColor,
  });

  final GameMode mode;
  final String nameKey;
  final PaperIconData icon;
  final Color accent;
  final Color paperColor;

  static const List<ModePresentation> all = [
    ModePresentation(
      mode: GameMode.classic,
      nameKey: 'mode.classic',
      icon: PaperIconData.glider,
      accent: AppColors.modeClassic,
      paperColor: AppColors.paperGold,
    ),
    ModePresentation(
      mode: GameMode.zen,
      nameKey: 'mode.zen',
      icon: PaperIconData.leaf,
      accent: AppColors.modeZen,
      paperColor: AppColors.paperGreen,
    ),
    ModePresentation(
      mode: GameMode.daily,
      nameKey: 'mode.daily',
      icon: PaperIconData.calendar,
      accent: AppColors.modeDaily,
      paperColor: AppColors.paperBlue,
    ),
    ModePresentation(
      mode: GameMode.trial,
      nameKey: 'mode.trial',
      icon: PaperIconData.bullseye,
      accent: AppColors.modeTrial,
      paperColor: AppColors.paperRose,
    ),
  ];

  static ModePresentation forMode(GameMode mode) =>
      all.firstWhere((m) => m.mode == mode);

  static ModePresentation atIndex(int index) =>
      all[index.clamp(0, all.length - 1)];
}

/// Darkens a colour for ink / fold-edge use on paper sheets.
Color darkenModeColor(Color c, [double amount = 0.2]) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

/// Mode icon medallion shared by the menu carousel and modes hub.
class ModeMedallion extends StatelessWidget {
  const ModeMedallion({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 44,
    this.iconSize = 24,
    this.radius = AppRadius.button,
  });

  final PaperIconData icon;
  final Color accent;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: PaperShadows.buttonEdge(accent),
      ),
      child: Center(
        child: PaperIcon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}

/// Compact mode preview sheet for the main-menu carousel.
class ModePreviewCard extends StatelessWidget {
  const ModePreviewCard({
    super.key,
    required this.presentation,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  final ModePresentation presentation;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final accent = presentation.accent;
    final edge = darkenModeColor(accent);

    return PaperCard(
      onTap: onTap,
      color: presentation.paperColor,
      radius: AppRadius.md,
      elevation: 1.0,
      textureOpacity: 0.45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: accent.withOpacity(0.5),
      borderWidth: 1.5,
      child: Row(
        children: [
          ModeMedallion(
            icon: presentation.icon,
            accent: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: edge,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.paperInkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showChevron) ...[
            Icon(Icons.chevron_right, color: edge, size: 18),
          ],
        ],
      ),
    );
  }
}
