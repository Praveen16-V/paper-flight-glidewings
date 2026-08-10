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

/// Operational daily & weekly challenges screen with 7-day stamp-card streak.
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
              _TitleBar(onRefresh: () => ref.read(saveDataProvider.notifier).refreshChallengesIfNeeded()),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(saveDataProvider.notifier).refreshChallengesIfNeeded(),
                  color: AppColors.accent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      _StreakStampCard(streak: save.dailyLoginStreak),
                      const SizedBox(height: 16),
                      // MiniStat row removed — redundant with currency display elsewhere
                      _SectionHeader(
                        title: "TODAY'S CHALLENGES",
                        subtitle: _dailySubtitle(save.lastDailyChallengeMs),
                        accentColor: AppColors.accent,
                        actionLabel: _hasClaimable(save.dailyChallengeCompleted, save.dailyChallengeClaimed) ? 'Claim all' : null,
                        onAction: _hasClaimable(save.dailyChallengeCompleted, save.dailyChallengeClaimed)
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
                          final prog = i < save.dailyChallengeProgress.length ? save.dailyChallengeProgress[i] : 0;
                          final completed = i < save.dailyChallengeCompleted.length ? save.dailyChallengeCompleted[i] : false;
                          final claimed = i < save.dailyChallengeClaimed.length ? save.dailyChallengeClaimed[i] : false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChallengeCard(definition: def, progress: prog, completed: completed, claimed: claimed, onClaim: completed && !claimed ? () => _claimOne(ChallengePeriod.daily, i) : null),
                          );
                        }),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'WEEKLY CHALLENGES',
                        subtitle: _weeklySubtitle(save.lastWeeklyChallengeMs),
                        accentColor: AppColors.accentAlt,
                        actionLabel: _hasClaimable(save.weeklyChallengeCompleted, save.weeklyChallengeClaimed) ? 'Claim all' : null,
                        onAction: _hasClaimable(save.weeklyChallengeCompleted, save.weeklyChallengeClaimed)
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
                          final prog = i < save.weeklyChallengeProgress.length ? save.weeklyChallengeProgress[i] : 0;
                          final completed = i < save.weeklyChallengeCompleted.length ? save.weeklyChallengeCompleted[i] : false;
                          final claimed = i < save.weeklyChallengeClaimed.length ? save.weeklyChallengeClaimed[i] : false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChallengeCard(definition: def, progress: prog, completed: completed, claimed: claimed, isWeekly: true, onClaim: completed && !claimed ? () => _claimOne(ChallengePeriod.weekly, i) : null),
                          );
                        }),
                      const SizedBox(height: 24),
                      Center(child: Text('Daily resets at midnight  •  Weekly resets Monday', style: AppTypography.caption.copyWith(fontSize: 11), textAlign: TextAlign.center)),
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
    final ids = period == ChallengePeriod.daily ? ref.read(saveDataProvider).dailyChallengeIds : ref.read(saveDataProvider).weeklyChallengeIds;
    final completed = period == ChallengePeriod.daily ? ref.read(saveDataProvider).dailyChallengeCompleted : ref.read(saveDataProvider).weeklyChallengeCompleted;
    final claimed = period == ChallengePeriod.daily ? ref.read(saveDataProvider).dailyChallengeClaimed : ref.read(saveDataProvider).weeklyChallengeClaimed;
    for (int i = 0; i < ids.length; i++) {
      if (i < completed.length && i < claimed.length && completed[i] && !claimed[i]) {
        await notifier.claimChallengeReward(period: period, index: i);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${period == ChallengePeriod.daily ? 'Daily' : 'Weekly'} rewards claimed!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _claimOne(ChallengePeriod period, int i) async {
    final res = await ref.read(saveDataProvider.notifier).claimChallengeReward(period: period, index: i);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Claimed +${res.$1} coins${res.$2 > 0 ? ' +${res.$2} gems' : ''}!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ));
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

  String _monthName(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
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
          IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textLight), onPressed: () => Navigator.of(context).pop()),
          Expanded(child: Text('Challenges', style: AppTypography.headline, textAlign: TextAlign.center)),
          IconButton(icon: const Icon(Icons.refresh, size: 20, color: AppColors.textLight), onPressed: onRefresh, tooltip: 'Refresh'),
        ],
      ),
    );
  }
}

// ── 7-Day Streak Stamp-Card ──────────────────────────────────────────────────

class _StreakStampCard extends StatelessWidget {
  const _StreakStampCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final normalized = streak.clamp(0, 7);
    return PaperCard(
      color: AppColors.paperGold,
      elevation: 1.5,
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: const [BoxShadow(color: AppColors.accentDeep, offset: Offset(0, 3), blurRadius: 0)],
                  ),
                  child: const Center(child: Text('🔥', style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$normalized Day Streak', style: AppTypography.title.copyWith(color: AppColors.paperInk, fontSize: 17)),
                    Text(normalized == 0 ? 'Start your streak today!' : 'Log in tomorrow to keep it going!',
                        style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 11)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.paperInk.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.paperInk.withOpacity(0.10))),
                  child: Text(normalized >= 7 ? 'Max!' : '${7 - normalized} to gift',
                      style: AppTypography.caption.copyWith(color: AppColors.paperInk, fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ],
            ),
          ),
          // dashed separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: AppColors.paperInkSoft.withOpacity(0.18))),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: List.generate(7, (i) {
                final day = i + 1;
                final isCompleted = i < normalized;
                final isMilestone = day == 7;
                final isNext = i == normalized && normalized < 7; // today's target
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
                    child: _DayStampBox(day: day, isCompleted: isCompleted, isMilestone: isMilestone, isNext: isNext),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: normalized / 7,
                      backgroundColor: AppColors.paperInkSoft.withOpacity(0.18),
                      valueColor: AlwaysStoppedAnimation<Color>(normalized >= 7 ? AppColors.success : AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$normalized / 7', style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontWeight: FontWeight.w800, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStampBox extends StatelessWidget {
  const _DayStampBox({required this.day, required this.isCompleted, required this.isMilestone, required this.isNext});
  final int day;
  final bool isCompleted;
  final bool isMilestone;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final bg = isCompleted
        ? (isMilestone ? AppColors.warning.withOpacity(0.22) : AppColors.success.withOpacity(0.16))
        : (isNext ? AppColors.accent.withOpacity(0.12) : Colors.white.withOpacity(0.72));
    final border = isCompleted
        ? (isMilestone ? AppColors.warning : AppColors.success)
        : (isNext ? AppColors.accent : AppColors.paperInkSoft.withOpacity(0.18));
    final borderWidth = isCompleted || isNext ? 1.6 : 1.1;

    return AspectRatio(
      aspectRatio: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: border, width: borderWidth),
          boxShadow: isCompleted && isMilestone
              ? [BoxShadow(color: AppColors.warning.withOpacity(0.32), blurRadius: 10, spreadRadius: 1), BoxShadow(color: AppColors.warning.withOpacity(0.18), blurRadius: 16)]
              : (isCompleted ? [BoxShadow(color: AppColors.success.withOpacity(0.18), blurRadius: 6)] : null),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                if (isMilestone)
                  SizedBox(width: 28, height: 24, child: CustomPaint(painter: _GiftBoxPainter(isCompleted: isCompleted))),
                if (isMilestone) const SizedBox(height: 3),
                if (!isMilestone || !isCompleted)
                  Icon(
                    isCompleted ? Icons.check_rounded : (isNext ? Icons.today_rounded : Icons.circle_outlined),
                    size: isCompleted ? 20 : 16,
                    color: isCompleted ? AppColors.success : (isNext ? AppColors.accent : AppColors.paperInkSoft.withOpacity(0.42)),
                  ),
                if (!isMilestone) const SizedBox(height: 4),
                Text(isMilestone ? 'DAY 7' : 'DAY $day',
                    style: AppTypography.overline.copyWith(
                        color: isCompleted
                            ? (isMilestone ? const Color(0xFF6D4C00) : AppColors.success)
                            : (isNext ? AppColors.accentDeep : AppColors.paperInkSoft),
                        fontSize: 7,
                        letterSpacing: 0.7)),
                if (isMilestone)
                  Text('GIFT',
                      style: AppTypography.overline.copyWith(
                          color: isCompleted ? const Color(0xFF6D4C00) : AppColors.paperInkSoft, fontSize: 7, letterSpacing: 1.0)),
              ],
            ),
          ),
            // origami checkmark stamp overlay for completed days (non-milestone)
            if (isCompleted && !isMilestone)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
            // stamped texture for completed
            if (isCompleted)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.07,
                    child: CustomPaint(painter: _StampGrainPainter()),
                  ),
                ),
              ),
            // today's pulse ring
            if (isNext)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.accent.withOpacity(0.0), width: 1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GiftBoxPainter extends CustomPainter {
  _GiftBoxPainter({required this.isCompleted});
  final bool isCompleted;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // shadow
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.72, w * 0.64, h * 0.18), const Radius.circular(2)),
        Paint()..color = Colors.black.withOpacity(0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // box base
    final base = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h * 0.38, w * 0.72, h * 0.42), const Radius.circular(3));
    final basePaint = Paint()..color = isCompleted ? const Color(0xFFFFC83D) : const Color(0xFFB0BEC5);
    canvas.drawRRect(base, basePaint);
    // lid
    final lid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.10, h * 0.28, w * 0.80, h * 0.18), const Radius.circular(3));
    final lidPaint = Paint()..color = isCompleted ? const Color(0xFFFFA000) : const Color(0xFF90A4AE);
    canvas.drawRRect(lid, lidPaint);
    // ribbon vertical
    final vRibbon = Rect.fromLTWH(w * 0.44, h * 0.28, w * 0.12, h * 0.52);
    canvas.drawRect(vRibbon, Paint()..color = isCompleted ? const Color(0xFFE53935) : const Color(0xFF78909C));
    // ribbon horizontal
    final hRibbon = Rect.fromLTWH(w * 0.10, h * 0.48, w * 0.80, h * 0.10);
    canvas.drawRect(hRibbon, Paint()..color = isCompleted ? const Color(0xFFE53935) : const Color(0xFF78909C));
    // bow
    final bowPaint = Paint()..color = isCompleted ? const Color(0xFFE53935) : const Color(0xFF78909C);
    canvas.drawCircle(Offset(w * 0.50, h * 0.28), 4.2, bowPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.38, h * 0.24), width: 10, height: 7), bowPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.24), width: 10, height: 7), bowPaint);
    // highlight
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.40, w * 0.22, h * 0.08), const Radius.circular(2)),
        Paint()..color = Colors.white.withOpacity(isCompleted ? 0.28 : 0.18));
    // glow when completed
    if (isCompleted) {
      final glow = Paint()
        ..color = AppColors.warning.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(w * 0.50, h * 0.42), 14, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _GiftBoxPainter old) => old.isCompleted != isCompleted;
}

class _StampGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF2A3354);
    final rnd = DateTime.now().microsecondsSinceEpoch % 1000;
    // subtle dots — deterministic-ish
    for (var i = 0; i < 18; i++) {
      final x = (i * 13 + rnd) % size.width;
      final y = (i * 7 + rnd * 2) % size.height;
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 0.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1..strokeCap = StrokeCap.round;
    double x = 0;
    const dash = 5.0;
    const gap = 5.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── rest reused from original ──────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});
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
      child: Column(children: [
        PaperIcon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        StatCounter(value, style: AppTypography.statSmall.copyWith(color: AppColors.paperInk, fontSize: 15)),
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 10)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.accentColor = AppColors.accent,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String subtitle;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Colored left-rule accent
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTypography.overline.copyWith(color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.caption.copyWith(fontSize: 11)),
            ]),
          ),
          if (actionLabel != null && onAction != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: PaperButton(
                label: actionLabel!,
                compact: true,
                onPressed: onAction,
                color: AppColors.success,
                textColor: Colors.white,
              ),
            ),
        ]),
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
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))));
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.definition, required this.progress, required this.completed, required this.claimed, this.isWeekly = false, this.onClaim});
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
      color: isDone ? AppColors.paperWarm : (isClaimable ? AppColors.paperGreen : AppColors.paper),
      elevation: isClaimable ? 1.4 : 1.0,
      padding: const EdgeInsets.all(14),
      borderColor: isClaimable ? AppColors.success : (isDone ? AppColors.success.withOpacity(0.35) : null),
      dogEar: isClaimable ? const DogEar(label: 'DONE', color: AppColors.success, size: 52) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: (isDone || isClaimable) ? AppColors.success.withOpacity(0.22) : AppColors.paperWarm,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: AppColors.paperInk.withOpacity(0.12), offset: const Offset(0, 2), blurRadius: 0)]),
              child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: AppColors.success, size: 20)
                      : PaperIcon(PaperIconData.bullseye, size: 20, color: isClaimable ? AppColors.success : AppColors.accent))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(definition.title,
                style: AppTypography.bodyLarge.copyWith(
                    color: isDone ? AppColors.paperInkSoft : AppColors.paperInk,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.paperInkSoft)),
            const SizedBox(height: 2),
            Text(definition.description, style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft)),
          ])),
          const SizedBox(width: 8),
          _RewardChip(coins: definition.rewardCoins, gems: definition.rewardGems, isClaimed: claimed),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.paperInkSoft.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(isDone ? AppColors.success : AppColors.accent),
                minHeight: 8)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isDone ? 'Completed' : '$progress / ${definition.target}',
              style: AppTypography.caption.copyWith(
                  color: isDone ? AppColors.success : AppColors.paperInkSoft,
                  fontWeight: isDone ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12)),
          if (!isDone)
            Text('${(pct * 100).toInt()}%',
                style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          if (isClaimable)
            PaperButton(label: 'CLAIM', compact: true, onPressed: onClaim, color: AppColors.success, textColor: Colors.white)
          else if (isDone)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.success.withOpacity(0.4))),
                child: Text('CLAIMED',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)))
          else
            Text(definition.isSingleRun ? 'in one run' : (isWeekly ? 'this week' : 'today'),
                style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 11, fontStyle: FontStyle.italic)),
        ]),
      ]),
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
    if (isClaimed) return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.paperBright,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(0.35)),
            boxShadow: PaperShadows.edge(AppColors.accent, dy: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (coins > 0) CoinChip(coins, iconSize: 11, fontSize: 11, spacing: 3),
          if (coins > 0 && gems > 0) const SizedBox(width: 6),
          if (gems > 0) GemChip(gems, iconSize: 10, fontSize: 11, spacing: 3),
        ]));
  }
}
