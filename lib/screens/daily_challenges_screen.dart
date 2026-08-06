import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/enums/game_enums.dart';
import '../models/challenge_definitions.dart';
import '../providers/save_data_provider.dart';

/// Operational daily & weekly challenges screen.
/// Shows real progress, claim buttons, streak, and refresh logic.
class DailyChallengesScreen extends ConsumerStatefulWidget {
  const DailyChallengesScreen({super.key});

  @override
  ConsumerState<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends ConsumerState<DailyChallengesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(saveDataProvider.notifier).refreshChallengesIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);

    // Ensure challenges exist — if still empty after microtask, show loader briefly
    final dailyIds = save.dailyChallengeIds;
    final weeklyIds = save.weeklyChallengeIds;
    final hasDaily = dailyIds.isNotEmpty;
    final hasWeekly = weeklyIds.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: const Text('Challenges', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.read(saveDataProvider.notifier).refreshChallengesIfNeeded(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(saveDataProvider.notifier).refreshChallengesIfNeeded(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Login streak card ──────────────────────────────────────
            _StreakCard(streak: save.dailyLoginStreak),
            const SizedBox(height: 20),

            // Quick stats
            Row(
              children: [
                Expanded(child: _MiniStat(label: 'Coins', value: '${save.coins}', color: AppColors.coinGold, icon: '●')),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(label: 'Gems', value: '${save.gems}', color: AppColors.gemBlue, icon: '◆')),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(label: 'Best', value: '${save.highScore}', color: AppColors.textLight, icon: '★')),
              ],
            ),
            const SizedBox(height: 20),

            // ── Daily header ───────────────────────────────────────────
            _SectionHeader(
              title: "TODAY'S CHALLENGES",
              subtitle: _dailySubtitle(save.lastDailyChallengeMs),
              actionLabel: _hasClaimable(save.dailyChallengeCompleted, save.dailyChallengeClaimed) ? 'Claim all' : null,
              onAction: _hasClaimable(save.dailyChallengeCompleted, save.dailyChallengeClaimed)
                  ? () async {
                      for (int i = 0; i < save.dailyChallengeIds.length; i++) {
                        if (save.dailyChallengeCompleted[i] && !save.dailyChallengeClaimed[i]) {
                          await ref.read(saveDataProvider.notifier).claimChallengeReward(period: ChallengePeriod.daily, index: i);
                        }
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Daily rewards claimed!'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            if (!hasDaily)
              const _EmptyChallengePlaceholder()
            else
              ...List.generate(dailyIds.length, (i) {
                final def = ChallengePool.byId(dailyIds[i]);
                if (def == null) return const SizedBox.shrink();
                final prog = i < save.dailyChallengeProgress.length ? save.dailyChallengeProgress[i] : 0;
                final completed = i < save.dailyChallengeCompleted.length ? save.dailyChallengeCompleted[i] : false;
                final claimed = i < save.dailyChallengeClaimed.length ? save.dailyChallengeClaimed[i] : false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChallengeCard(
                    definition: def,
                    progress: prog,
                    completed: completed,
                    claimed: claimed,
                    onClaim: completed && !claimed
                        ? () async {
                            final res = await ref.read(saveDataProvider.notifier).claimChallengeReward(period: ChallengePeriod.daily, index: i);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Claimed +${res.$1} coins${res.$2 > 0 ? ' +${res.$2} gems' : ''}!'),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                );
              }),

            const SizedBox(height: 20),

            // ── Weekly header ──────────────────────────────────────────
            _SectionHeader(
              title: 'WEEKLY CHALLENGES',
              subtitle: _weeklySubtitle(save.lastWeeklyChallengeMs),
              actionLabel: _hasClaimable(save.weeklyChallengeCompleted, save.weeklyChallengeClaimed) ? 'Claim all' : null,
              onAction: _hasClaimable(save.weeklyChallengeCompleted, save.weeklyChallengeClaimed)
                  ? () async {
                      for (int i = 0; i < save.weeklyChallengeIds.length; i++) {
                        if (save.weeklyChallengeCompleted[i] && !save.weeklyChallengeClaimed[i]) {
                          await ref.read(saveDataProvider.notifier).claimChallengeReward(period: ChallengePeriod.weekly, index: i);
                        }
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Weekly rewards claimed!'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            if (!hasWeekly)
              const _EmptyChallengePlaceholder()
            else
              ...List.generate(weeklyIds.length, (i) {
                final def = ChallengePool.byId(weeklyIds[i]);
                if (def == null) return const SizedBox.shrink();
                final prog = i < save.weeklyChallengeProgress.length ? save.weeklyChallengeProgress[i] : 0;
                final completed = i < save.weeklyChallengeCompleted.length ? save.weeklyChallengeCompleted[i] : false;
                final claimed = i < save.weeklyChallengeClaimed.length ? save.weeklyChallengeClaimed[i] : false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChallengeCard(
                    definition: def,
                    progress: prog,
                    completed: completed,
                    claimed: claimed,
                    isWeekly: true,
                    onClaim: completed && !claimed
                        ? () async {
                            final res = await ref.read(saveDataProvider.notifier).claimChallengeReward(period: ChallengePeriod.weekly, index: i);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Claimed +${res.$1} coins${res.$2 > 0 ? ' +${res.$2} gems' : ''}!'),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                );
              }),

            const SizedBox(height: 28),
            const Center(
              child: Text(
                'Daily resets at midnight  •  Weekly resets Monday',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.textMuted),
                label: const Text('Back to Menu', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  String _monthName(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('🔥', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak Day Streak',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Text('Log in tomorrow to keep it going!', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
            child: Text(
              streak >= 7 ? 'Max!' : '${7 - streak} to bonus',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: [
          Text(icon, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, this.actionLabel, this.onAction});
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
              Text(title,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), border: Border.all(color: AppColors.success), borderRadius: BorderRadius.circular(20)),
              child: Text(actionLabel!, style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class _EmptyChallengePlaceholder extends StatelessWidget {
  const _EmptyChallengePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isClaimable
              ? AppColors.success
              : isDone
                  ? AppColors.success.withOpacity(0.35)
                  : AppColors.divider,
          width: isClaimable ? 1.4 : 1,
        ),
        boxShadow: isClaimable ? [BoxShadow(color: AppColors.success.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 3))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success.withOpacity(0.18)
                      : isClaimable
                          ? AppColors.success.withOpacity(0.22)
                          : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDone || isClaimable ? AppColors.success.withOpacity(0.5) : AppColors.divider),
                ),
                child: Center(
                  child: Text(
                    isDone ? '✓' : (definition.icon ?? '🎯'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: TextStyle(
                        color: isDone ? AppColors.textMuted : AppColors.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      definition.description,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RewardChip(coins: definition.rewardCoins, gems: definition.rewardGems, isClaimed: claimed),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(isDone ? AppColors.success : (completed ? AppColors.success : AppColors.accent)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDone ? 'Completed' : '$progress / ${definition.target}',
                style: TextStyle(
                  color: isDone ? AppColors.success : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (isClaimable)
                GestureDetector(
                  onTap: onClaim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF56CF87), Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Text('CLAIM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                )
              else if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.success.withOpacity(0.4)),
                  ),
                  child: const Text('CLAIMED ✓', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                )
              else
                Text(
                  definition.isSingleRun ? 'in one run' : (isWeekly ? 'this week' : 'today'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.coins, required this.gems, required this.isClaimed});
  final int coins;
  final int gems;
  final bool isClaimed;

  @override
  Widget build(BuildContext context) {
    if (isClaimed) {
      return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coins > 0) ...[
            const Text('●', style: TextStyle(color: AppColors.coinGold, fontSize: 10)),
            const SizedBox(width: 3),
            Text('$coins', style: const TextStyle(color: AppColors.coinGold, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
          if (coins > 0 && gems > 0) const SizedBox(width: 6),
          if (gems > 0) ...[
            const Text('◆', style: TextStyle(color: AppColors.gemBlue, fontSize: 10)),
            const SizedBox(width: 3),
            Text('$gems', style: const TextStyle(color: AppColors.gemBlue, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}
