import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../core/widgets/stat_counter.dart';
import '../models/trial_definition.dart';
import '../providers/game_session_provider.dart';
import 'game_screen.dart';

/// Route args for the trial results screen.
class TrialResultArgs {
  const TrialResultArgs({this.outcome});
  final TrialOutcome? outcome;
}

/// Results screen shown after a Precision Trial finishes.
class TrialResultsScreen extends StatefulWidget {
  const TrialResultsScreen({super.key, required this.args});
  final TrialResultArgs args;

  @override
  State<TrialResultsScreen> createState() => _TrialResultsScreenState();
}

class _TrialResultsScreenState extends State<TrialResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  TrialOutcome? get _outcome => widget.args.outcome;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    final trial =
        outcome == null ? null : TrialPool.byId(outcome.trialId);
    final completed = outcome?.completed == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceAlt, AppColors.backgroundDeep],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeIn),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Text(
                    outcome == null
                        ? 'TRIAL'
                        : completed
                            ? 'COURSE COMPLETE'
                            : outcome.timedOut
                                ? 'TIME UP'
                                : 'CRASHED',
                    style: AppTypography.displayMedium.copyWith(
                      color: completed
                          ? AppColors.success
                          : AppColors.danger,
                      fontSize: 26,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(trial?.title ?? '', style: AppTypography.caption),
                  const SizedBox(height: 24),
                  if (outcome != null) ...[
                    _StarsRow(stars: outcome.stars, anim: _anim),
                    if (outcome.isNewBestStars) ...[
                      const SizedBox(height: 10),
                      Text('★ NEW BEST!',
                          style: AppTypography.label.copyWith(
                              color: AppColors.warning,
                              letterSpacing: 2,
                              fontSize: 14)),
                    ],
                    if (!completed) ...[
                      const SizedBox(height: 10),
                      Text(
                        outcome.timedOut
                            ? 'The clock ran out — fly faster!'
                            : 'One touch ends the run — try again!',
                        style: AppTypography.caption.copyWith(fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(height: 28),
                    PaperCard(
                      color: completed
                          ? AppColors.paperGreen
                          : AppColors.paperRose,
                      elevation: 1.6,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      dogEar: completed
                          ? const DogEar(
                              label: 'DONE',
                              color: AppColors.success,
                              size: 56)
                          : null,
                      child: Column(
                        children: [
                          _StatRow(
                            label: 'Time',
                            value: outcome.timeUsedSeconds,
                            suffix: ' s',
                          ),
                          Divider(
                              color:
                                  AppColors.paperInkSoft.withOpacity(0.25),
                              height: 18),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  PaperIcon(PaperIconData.coin,
                                      size: 14, color: AppColors.coinGold),
                                  const SizedBox(width: 6),
                                  Text('Coins',
                                      style: AppTypography.bodyMedium
                                          .copyWith(
                                              color: AppColors.paperInkSoft)),
                                ],
                              ),
                              StatCounter(
                                outcome.coinsCollected,
                                suffix: '/${outcome.totalCoins}',
                                style: AppTypography.statSmall.copyWith(
                                    color: AppColors.coinGoldDeep),
                              ),
                            ],
                          ),
                          if (trial?.parSeconds != null) ...[
                            Divider(
                                color: AppColors.paperInkSoft
                                    .withOpacity(0.25),
                                height: 18),
                            _StatRow(
                              label: 'Par',
                              value: trial!.parSeconds!,
                              suffix: ' s',
                              valueColor: AppColors.paperInk,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (trial != null) ...[
                    PaperButton(
                      label: 'FLY AGAIN',
                      expand: true,
                      onPressed: () => _retry(trial),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PaperButton(
                            label: 'MENU',
                            expand: true,
                            color: AppColors.paperWarm,
                            textColor: AppColors.paperInk,
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.trials),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PaperButton(
                            label: 'TRIALS',
                            expand: true,
                            color: AppColors.paperBlue,
                            textColor: AppColors.gemBlueDeep,
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.trials),
                          ),
                        ),
                      ],
                    ),
                    if (outcome?.completed == true &&
                        outcome!.stars >= 1) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => _nextTrial(trial),
                        child: Text(
                          'NEXT TRIAL →',
                          style: AppTypography.label.copyWith(
                              color: AppColors.accentAlt, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _retry(TrialDefinition trial) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.game,
      arguments: GameScreenArgs(mode: GameMode.trial, trialId: trial.id),
    );
  }

  void _nextTrial(TrialDefinition trial) {
    final next = TrialPool.byId(trial.id + 1);
    if (next == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.trials);
      return;
    }
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.game,
      arguments: GameScreenArgs(mode: GameMode.trial, trialId: next.id),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.stars, required this.anim});
  final int stars;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int s = 1; s <= 3; s++)
          ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: anim,
                curve: Interval(
                  (s - 1) * 0.22,
                  0.2 + s * 0.22,
                  curve: Curves.elasticOut,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                s <= stars ? Icons.star : Icons.star_border,
                size: 54,
                color: s <= stars
                    ? AppColors.warning
                    : AppColors.textMuted.withOpacity(0.4),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.suffix = '',
    this.valueColor,
  });
  final String label;
  final double value;
  final String suffix;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.paperInkSoft)),
        StatCounter(
          value,
          suffix: suffix,
          style: AppTypography.stat.copyWith(
            color: valueColor ?? AppColors.paperInk,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
