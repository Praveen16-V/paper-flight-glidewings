import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
import 'game_screen.dart';

/// Game Modes hub (Task 8) — the four ways to fly:
///  ✈️ Classic   — the endless arcade original.
///  🍃 Zen      — no crashes, calm skies, infinite gliding.
///  🗓️ Daily    — one seeded run per UTC day, same wind for everyone.
///  🎯 Trials   — six handcrafted precision courses with star ratings.
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'GAME MODES',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Four ways to fly',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _ModeCard(
                    icon: GameMode.classic.icon,
                    title: GameMode.classic.displayName,
                    subtitle: GameMode.classic.tagline,
                    accent: AppColors.accent,
                    onTap: () => _play(context, mode: GameMode.classic),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    icon: GameMode.zen.icon,
                    title: GameMode.zen.displayName,
                    subtitle: GameMode.zen.tagline,
                    accent: AppColors.success,
                    onTap: () => _play(context, mode: GameMode.zen),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    icon: GameMode.daily.icon,
                    title: GameMode.daily.displayName,
                    subtitle: GameMode.daily.tagline,
                    accent: AppColors.accentAlt,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.dailyFlight),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    icon: GameMode.trial.icon,
                    title: GameMode.trial.displayName,
                    subtitle: GameMode.trial.tagline,
                    accent: AppColors.gemBlue,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.trials),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _play(BuildContext context, {required GameMode mode}) {
    Navigator.of(context).pushNamed(
      AppRoutes.game,
      arguments: GameScreenArgs(mode: mode),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
  final String icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.45), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
