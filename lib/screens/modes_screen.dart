import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_effects.dart';
import '../core/widgets/paper_icons.dart';
import 'game_screen.dart';

/// Game Modes hub — four ways to fly, presented as folded paper sheets.
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceAlt, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'GAME MODES',
                style: AppTypography.displayMedium
                    .copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text('Four ways to fly', style: AppTypography.caption),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                  for (final mode in GameMode.values) ...[
                    _ModeCard(
                      icon: mode.paperIcon,
                      title: mode.displayName,
                      subtitle: mode.tagline,
                      accent: _accentFor(mode),
                      sheet: mode.paperColor,
                      dogEar: mode == GameMode.daily ? 'TODAY' : null,
                      onTap: () => _onModeTap(context, mode),
                    ),
                    if (mode != GameMode.values.last)
                      const SizedBox(height: 16),
                  ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onModeTap(BuildContext context, GameMode mode) {
    if (mode == GameMode.daily) {
      Navigator.of(context).pushNamed(AppRoutes.dailyFlight);
    } else if (mode == GameMode.trial) {
      Navigator.of(context).pushNamed(AppRoutes.trials);
    } else {
      Navigator.of(context).pushNamed(
        AppRoutes.game,
        arguments: GameScreenArgs(mode: mode),
      );
    }
  }

  Color _accentFor(GameMode mode) {
    switch (mode) {
      case GameMode.classic:
        return AppColors.accent;
      case GameMode.zen:
        return AppColors.success;
      case GameMode.daily:
        return AppColors.accentAlt;
      case GameMode.trial:
        return AppColors.danger;
    }
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.sheet,
    required this.onTap,
    this.dogEar,
  });

  final PaperIconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color sheet;
  final VoidCallback onTap;
  final String? dogEar;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      color: sheet,
      edgeColor: _edgeOf(sheet),
      elevation: 1.2,
      padding: const EdgeInsets.all(16),
      dogEar: dogEar != null
          ? DogEar(label: dogEar!, color: accent, size: 60)
          : null,
      child: Row(
        children: [
          // Folded paper medallion.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withOpacity(0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _edgeOf(accent),
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
                ...PaperShadows.stack(
                    color: AppColors.paperInk, elevation: 0.5),
              ],
            ),
            child: Center(
              child: PaperIcon(icon, size: 30, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.title.copyWith(
                    color: _edgeOf(accent),
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.paperInkSoft,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: AppColors.paperInkSoft, size: 24),
        ],
      ),
    );
  }

  Color _edgeOf(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();
  }
}
