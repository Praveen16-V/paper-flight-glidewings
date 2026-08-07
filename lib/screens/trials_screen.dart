import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../models/trial_definition.dart';
import '../providers/save_data_provider.dart';
import 'game_screen.dart';

/// Precision Trials hub — six handcrafted courses.
class TrialsScreen extends ConsumerWidget {
  const TrialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(saveDataProvider);

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
              _TitleBar(),
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TrialCard(
                        trial: trial,
                        stars: stars,
                        unlocked: unlocked,
                        onTap: unlocked
                            ? () => Navigator.of(context).pushNamed(
                                  AppRoutes.game,
                                  arguments: GameScreenArgs(
                                    mode: GameMode.trial,
                                    trialId: trial.id,
                                  ),
                                )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text('PRECISION TRIALS',
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMedium
                        .copyWith(fontSize: 22, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text('Handcrafted courses • earn your stars',
                    style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
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
    final sheet = unlocked ? AppColors.paper : AppColors.paperWarm;
    return PaperCard(
      onTap: onTap,
      color: sheet,
      elevation: unlocked ? 1.2 : 0.8,
      padding: const EdgeInsets.all(16),
      dogEar: stars >= 3
          ? const DogEar(label: '3★', color: AppColors.warning, size: 56)
          : null,
      child: Opacity(
        opacity: unlocked ? 1 : 0.6,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: unlocked
                    ? AppColors.danger.withOpacity(0.16)
                    : AppColors.paperInkSoft.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: unlocked
                    ? PaperIcon(PaperIconData.bullseye,
                        size: 24, color: AppColors.danger)
                    : const Icon(Icons.lock_outline,
                        color: AppColors.paperInkSoft, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trial.title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.paperInk,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trial.flavor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.paperInkSoft, fontSize: 11.5),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (int s = 1; s <= 3; s++)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            s <= stars ? Icons.star : Icons.star_border,
                            size: 17,
                            color: s <= stars
                                ? AppColors.warning
                                : AppColors.paperInkSoft.withOpacity(0.5),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (trial.parSeconds != null)
                        Text(
                          'PAR ${trial.parSeconds!.toStringAsFixed(0)}s',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.paperInkSoft,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      if (trial.totalCoins > 0) ...[
                        const SizedBox(width: 8),
                        PaperIcon(PaperIconData.coin,
                            size: 10, color: AppColors.coinGold),
                        const SizedBox(width: 3),
                        Text(
                          '${trial.totalCoins}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.coinGoldDeep,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
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
              color: unlocked ? AppColors.danger : AppColors.paperInkSoft,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}
