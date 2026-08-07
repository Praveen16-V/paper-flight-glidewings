import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_effects.dart';
import '../core/widgets/paper_icons.dart';
import '../core/widgets/stat_counter.dart';
import '../models/challenge_definitions.dart';
import '../providers/save_data_provider.dart';

/// Operational daily & weekly challenges screen.
class DailyChallengesScreen extends ConsumerStatefulWidget {
  const DailyChallengesScreen({super.key});

  @override
  ConsumerState<DailyChallengesScreen> createState() =>
      _DailyChallengesScreenState();
}

class _DailyChallengesScreenState
    extends ConsumerState<DailyChallengesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(saveDataProvider.notifier).refreshChallengesIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final dailyIds = save.dailyChallengeIds;
    final weeklyIds = save.weeklyChallengeIds;
    final hasDaily = dailyIds.isNotEmpty;
    final hasWeekly = weeklyIds.isNotEmpty;

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
              _TitleBar(
                onRefresh: () => ref
                    .read(saveDataProvider.notifier)
                    .refreshChallengesIfNeeded(),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(saveDataProvider.notifier)
                      .refreshChallengesIfNeeded(),
                  color: AppColors.accent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      _StreakCard(streak: save.dailyLoginStreak),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _MiniStat(
                                  label: 'Coins',
                                  value: save.coins,
                                  icon: PaperIconData.coin,
                                  color: AppColors.coinGold)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MiniStat(
                                  label: 'Gems',
                                  value: save.gems,
                                  icon: PaperIconData.gem,
                                  color: AppColors.gemBlue)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MiniStat(
                                  label: 'Best',
                                  value: save.highScore,
                                  icon: PaperIconData.bullseye,
                                  color: AppColors.accent)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: "TODAY'S CHALLENGES",
                        subtitle: _dailySubtitle(save.lastDailyChallengeMs),
                        actionLabel: _hasClaimable(
                                save.dailyChallengeCompleted,
                                save.dailyChallengeClaimed)
                            ? 'Claim all'
                            : null,
                        onAction: _hasClaimable(save.dailyChallengeCompleted,
                                save.dailyChallengeClaimed)
                            ? () => _claimAll(ChallengePeriod.daily)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      if (!hasDaily)
                        const _EmptyChallengePlaceholder()
                      else
                        ...List.generate(dailyIds.length, (i) {
                          final def = ChallengePool.byId(dailyIds[i]);
                          if (def == null) return const SizedBox.shrink();
                          final prog = i < save.dailyChallengeProgress.length
                              ? save.dailyChallengeProgress[i]
                              : 0;
                          final completed = i <
                                  save.dailyChallengeCompleted.length
                              ? save.dailyChallengeCompleted[i]
                              : false;
                          final claimed =
                              i < save.dailyChallengeClaimed.length
                                  ? save.dailyChallengeClaimed[i]
                                  : false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChallengeCard(
                              definition: def,
                              progress: prog,
                              completed: completed,
                              claimed: claimed,
                              onClaim: completed && !claimed
                                  ? () => _claimOne(
                                      ChallengePeriod.daily, i)
                                  : null,
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'WEEKLY CHALLENGES',
                        subtitle: _weeklySubtitle(save.lastWeeklyChallengeMs),
                        actionLabel: _hasClaimable(
                                save.weeklyChallengeCompleted,
                                save.weeklyChallengeClaimed)
                            ? 'Claim all'
                            : null,
                        onAction: _hasClaimable(save.weeklyChallengeCompleted,
                                save.weeklyChallengeClaimed)
                            ? () => _claimAll(ChallengePeriod.weekly)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      if (!hasWeekly)
                        const _EmptyChallengePlaceholder()
                      else
                        ...List.generate(weeklyIds.length, (i) {
                          final def = ChallengePool.byId(weeklyIds[i]);
                          if (def == null) return const SizedBox.shrink();
                          final prog = i < save.weeklyChallengeProgress.length
                              ? save.weeklyChallengeProgress[i]
                              : 0;
                          final completed = i <
                                  save.weeklyChallengeCompleted.length
                              ? save.weeklyChallengeCompleted[i]
                              : false;
                          final claimed =
                              i < save.weeklyChallengeClaimed.length
                                  ? save.weeklyChallengeClaimed[i]
                                  : false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChallengeCard(
                              definition: def,
                              progress: prog,
                              completed: completed,
                              claimed: claimed,
                              isWeekly: true,
                              onClaim: completed && !claimed
                                  ? () => _claimOne(
                                      ChallengePeriod.weekly, i)
                                  : null,
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Daily resets at midnight  •  Weekly resets Monday',
                          style: AppTypography.caption.copyWith(fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claimAll(ChallengePeriod period) async {
    final notifier = ref.read(saveDataProvider.notifier);
    final ids = period == ChallengePeriod.daily
        ? ref.read(saveDataProvider).dailyChallengeIds
        : ref.read(saveDataProvider).weeklyChallengeIds;
    final completed = period == ChallengePeriod.daily
        ? ref.read(saveDataProvider).dailyChallengeCompleted
        : ref.read(saveDataProvider).weeklyChallengeCompleted;
    final claimed = period == ChallengePeriod.daily
        ? ref.read(saveDataProvider).dailyChallengeClaimed
        : ref.read(saveDataProvider).weeklyChallengeClaimed;
    for (int i = 0; i < ids.length; i++) {
      if (i < completed.length && i < claimed.length &&
          completed[i] && !claimed[i]) {
        await notifier.claimChallengeReward(period: period, index: i);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${period == ChallengePeriod.daily ? 'Daily' : 'Weekly'} rewards claimed!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _claimOne(ChallengePeriod period, int i) async {
    final res = await ref
        .read(saveDataProvider.notifier)
        .claimChallengeReward(period: period, index: i);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Claimed +${res.$1} coins${res.$2 > 0 ? ' +${res.$2} gems' : ''}!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _hasClaimable(List<bool> completed, List<bool> claimed) {
    for (int i = 0; i < completed.length; i++) {
      if (i < claimed.length && completed[i] && !claimed[i]) return true;
    }
    return false;
  }

  String _dailySubtitle(int ms) {
    if (ms == 0) return 'Refreshing...';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return 'For ${_monthName(d.month)} ${d.day}  •  Resets at midnight';
  }

  String _weeklySubtitle(int ms) {
    if (ms == 0) return 'Refreshing...';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final end = d.add(const Duration(days: 6));
    return '${_monthName(d.month)} ${d.day} – ${_monthName(end.month)} ${end.day}';
  }

  String _monthName(int m) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
          'Oct', 'Nov', 'Dec'][m - 1];
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text('Challenges',
                style: AppTypography.headline, textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.textLight),
            onPressed: onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paperGold,
      elevation: 1.4,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.accentDeep,
                    offset: Offset(0, 3),
                    blurRadius: 0),
              ],
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$streak Day Streak',
                    style: AppTypography.title
                        .copyWith(color: AppColors.paperInk)),
                Text('Log in tomorrow to keep it going!',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.paperInkSoft)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              streak >= 7 ? 'Max!' : '${7 - streak} to bonus',
              style: AppTypography.caption.copyWith(
                  color: AppColors.paperInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final PaperIconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paperBright,
      elevation: 0.8,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          PaperIcon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          StatCounter(value,
              style: AppTypography.statSmall
                  .copyWith(color: AppColors.paperInk, fontSize: 15)),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.paperInkSoft, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title,
      required this.subtitle,
      this.actionLabel,
      this.onAction});
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.overline),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTypography.caption),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          PaperButton(
            label: actionLabel!,
            compact: true,
            onPressed: onAction,
            color: AppColors.success,
            textColor: Colors.white,
          ),
      ],
    );
  }
}

class _EmptyChallengePlaceholder extends StatelessWidget {
  const _EmptyChallengePlaceholder();

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paper,
      padding: const EdgeInsets.all(20),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.definition,
    required this.progress,
    required this.completed,
    required this.claimed,
    this.isWeekly = false,
    this.onClaim,
  });

  final ChallengeDefinition definition;
  final int progress;
  final bool completed;
  final bool claimed;
  final bool isWeekly;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final pct = (progress / definition.target).clamp(0.0, 1.0);
    final isClaimable = completed && !claimed;
    final isDone = completed && claimed;

    return PaperCard(
      color: isDone
          ? AppColors.paperWarm
          : (isClaimable ? AppColors.paperGreen : AppColors.paper),
      elevation: isClaimable ? 1.4 : 1.0,
      padding: const EdgeInsets.all(14),
      borderColor: isClaimable
          ? AppColors.success
          : (isDone ? AppColors.success.withOpacity(0.35) : null),
      dogEar: isClaimable
          ? const DogEar(label: 'DONE', color: AppColors.success, size: 52)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isDone || isClaimable)
                      ? AppColors.success.withOpacity(0.22)
                      : AppColors.paperWarm,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.paperInk.withOpacity(0.12),
                      offset: const Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check,
                          color: AppColors.success, size: 20)
                      : PaperIcon(PaperIconData.bullseye,
                          size: 20,
                          color: isClaimable
                              ? AppColors.success
                              : AppColors.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: AppTypography.bodyLarge.copyWith(
                        color: isDone
                            ? AppColors.paperInkSoft
                            : AppColors.paperInk,
                        fontSize: 14,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.paperInkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(definition.description,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.paperInkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RewardChip(
                  coins: definition.rewardCoins,
                  gems: definition.rewardGems,
                  isClaimed: claimed),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.paperInkSoft.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? AppColors.success : AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDone
                    ? 'Completed'
                    : '$progress / ${definition.target}',
                style: AppTypography.caption.copyWith(
                  color: isDone
                      ? AppColors.success
                      : AppColors.paperInkSoft,
                  fontWeight: isDone ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (isClaimable)
                PaperButton(
                  label: 'CLAIM',
                  compact: true,
                  onPressed: onClaim,
                  color: AppColors.success,
                  textColor: Colors.white,
                )
              else if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.success.withOpacity(0.4)),
                  ),
                  child: Text('CLAIMED',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                )
              else
                Text(
                  definition.isSingleRun
                      ? 'in one run'
                      : (isWeekly ? 'this week' : 'today'),
                  style: AppTypography.caption.copyWith(
                      color: AppColors.paperInkSoft,
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip(
      {required this.coins, required this.gems, required this.isClaimed});
  final int coins;
  final int gems;
  final bool isClaimed;

  @override
  Widget build(BuildContext context) {
    if (isClaimed) {
      return const Icon(Icons.check_circle,
          color: AppColors.success, size: 20);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paperBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
        boxShadow: PaperShadows.edge(AppColors.accent, dy: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coins > 0) ...[
            CoinChip(coins, iconSize: 11, fontSize: 11, spacing: 3),
          ],
          if (coins > 0 && gems > 0) const SizedBox(width: 6),
          if (gems > 0) ...[
            GemChip(gems, iconSize: 10, fontSize: 11, spacing: 3),
          ],
        ],
      ),
    );
  }
}
