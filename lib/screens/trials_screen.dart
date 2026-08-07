import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
import '../models/trial_definition.dart';
import '../providers/save_data_provider.dart';
import 'game_screen.dart';

/// Precision Trials hub (Task 8) — six handcrafted courses.
///
/// Progression: trial N is unlocked once trial N−1 has at least one star.
/// Stars are bragging-rights progression only — trials never award coins.
class TrialsScreen extends ConsumerWidget {
  const TrialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the save so star ratings refresh when a trial result lands.
    ref.watch(saveDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'PRECISION TRIALS',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Handcrafted courses • earn your stars',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: TrialPool.all.length,
                itemBuilder: (context, i) {
                  final trial = TrialPool.all[i];
                  final stars = ref
                      .read(saveDataProvider.notifier)
                      .trialBestStars(trial.id);
                  final previousStars = i == 0
                      ? 1
                      : ref
                          .read(saveDataProvider.notifier)
                          .trialBestStars(TrialPool.all[i - 1].id);
                  final unlocked = trial.isUnlockedBy(previousStars);

                  return _TrialCard(
                    trial: trial,
                    stars: stars,
                    unlocked: unlocked,
                    onTap: unlocked
                        ? () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.game,
                              arguments: GameScreenArgs(
                                mode: GameMode.trial,
                                trialId: trial.id,
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({
    required this.trial,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });
  final TrialDefinition trial;
  final int stars;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: unlocked ? AppColors.surface : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: unlocked
                    ? AppColors.gemBlue.withOpacity(0.4)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                // ── Icon / lock ──────────────────────────────────────────
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? AppColors.gemBlue.withOpacity(0.14)
                        : AppColors.divider.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      unlocked ? trial.icon : '🔒',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // ── Title + objective ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trial.title,
                        style: TextStyle(
                          color: unlocked
                              ? AppColors.textLight
                              : AppColors.textMuted,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trial.flavor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Star rating earned
                          for (int s = 1; s <= 3; s++)
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                s <= stars ? Icons.star : Icons.star_border,
                                size: 17,
                                color: s <= stars
                                    ? AppColors.warning
                                    : AppColors.divider,
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (trial.parSeconds != null)
                            Text(
                              'PAR ${trial.parSeconds!.toStringAsFixed(0)}s',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          if (trial.totalCoins > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${trial.totalCoins} COINS',
                              style: const TextStyle(
                                color: AppColors.coinGold,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  unlocked ? Icons.play_circle_fill : Icons.lock_outline,
                  color: unlocked ? AppColors.gemBlue : AppColors.divider,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
