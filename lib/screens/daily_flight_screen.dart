import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../core/widgets/stat_counter.dart';
import '../providers/save_data_provider.dart';
import '../services/daily_leaderboard_service.dart';
import '../services/daily_seed_service.dart';
import 'game_screen.dart';

/// Pre-flight hub for the Daily Seeded Flight.
class DailyFlightScreen extends ConsumerStatefulWidget {
  const DailyFlightScreen({super.key});

  @override
  ConsumerState<DailyFlightScreen> createState() => _DailyFlightScreenState();
}

class _DailyFlightScreenState extends ConsumerState<DailyFlightScreen> {
  late final int _seed = DailySeedService.seedForNow();
  Timer? _ticker;

  DailyLeaderboardResult? _best;
  List<DailyLeaderboardEntry> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadBoard();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadBoard() async {
    try {
      final best = await DailyLeaderboard.instance.bestForSeed(_seed);
      final recent =
          await DailyLeaderboard.instance.recentEntries(limit: 5);
      if (mounted) {
        setState(() {
          _best = best;
          _recent = recent;
        });
      }
    } catch (_) {}
  }

  Duration get _timeToReset {
    final now = DateTime.now();
    return DailySeedService.nextResetUtc(now).difference(now.toUtc());
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final attemptUsed =
        save.dailyLastSeed == _seed && save.dailyAttemptUsed;
    final reset = _timeToReset;

    final hh = reset.inHours.toString().padLeft(2, '0');
    final mm = (reset.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (reset.inSeconds % 60).toString().padLeft(2, '0');

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
              _BackBar(title: DailySeedService.label(_seed)),
              const SizedBox(height: 4),
              Text(
                "TODAY'S SEEDED FLIGHT",
                style: AppTypography.overline,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.paperBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 3),
                        blurRadius: 0),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PaperIcon(PaperIconData.calendar,
                        size: 16, color: AppColors.gemBlueDeep),
                    const SizedBox(width: 8),
                    Text(
                      'Next seed in  $hh:$mm:$ss',
                      style: AppTypography.statSmall.copyWith(
                        color: AppColors.gemBlueDeep,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _InfoCard(
                      lines: const [
                        'The wind, obstacles and coins come from today\'s seed — identical for every player worldwide.',
                        'One attempt per day (UTC). Quitting mid-run counts as your attempt.',
                        'The award is your place on the daily board. This run doesn\'t bank coins or progress challenges.',
                      ],
                    ),
                    const SizedBox(height: 14),
                    PaperCard(
                      color: attemptUsed
                          ? AppColors.paperRose
                          : AppColors.paperGreen,
                      elevation: 1.2,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            attemptUsed
                                ? Icons.lock_clock
                                : Icons.check_circle_outline,
                            color: attemptUsed
                                ? AppColors.danger
                                : AppColors.success,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              attemptUsed
                                  ? 'Today\'s attempt used. Come back tomorrow for a fresh seed!'
                                  : 'Attempt available — make it count!',
                              style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.paperInk, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    PaperCard(
                      color: AppColors.paperGold,
                      elevation: 1.2,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_outlined,
                              color: AppColors.accentDeep, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOUR BEST FOR THIS SEED',
                                    style: AppTypography.overline.copyWith(
                                        color: AppColors.paperInkSoft,
                                        fontSize: 10.5,
                                        letterSpacing: 1.5)),
                                const SizedBox(height: 6),
                                _best == null
                                    ? Text('— not flown yet —',
                                        style: AppTypography.caption.copyWith(
                                            color: AppColors.paperInkSoft,
                                            fontSize: 15))
                                    : Row(
                                        children: [
                                          StatCounter(_best!.score,
                                              suffix: ' pts',
                                              style: AppTypography.stat
                                                  .copyWith(
                                                      color: AppColors
                                                          .paperInk,
                                                      fontSize: 17)),
                                          const SizedBox(width: 10),
                                          Text('•',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: AppColors
                                                          .paperInkSoft)),
                                          const SizedBox(width: 10),
                                          StatCounter(_best!.distanceMeters,
                                              suffix: ' m',
                                              style: AppTypography.statSmall
                                                  .copyWith(
                                                      color: AppColors
                                                          .paperInkSoft,
                                                      fontSize: 14)),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_recent.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('RECENT FLIGHTS',
                            style: AppTypography.overline),
                      ),
                      PaperCard(
                        color: AppColors.paper,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        child: Column(
                          children: _recent.map((e) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Text(
                                    DailySeedService.label(
                                        DailySeedService.seedForDate(
                                            e.dateUtc)),
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.paperInkSoft,
                                        fontSize: 11),
                                  ),
                                  const Spacer(),
                                  StatCounter(e.score,
                                      suffix: ' pts',
                                      style: AppTypography.statSmall
                                          .copyWith(
                                              color: AppColors.paperInk,
                                              fontSize: 13)),
                                  const SizedBox(width: 10),
                                  StatCounter(e.distanceMeters,
                                      suffix: ' m',
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.paperInkSoft,
                                          fontSize: 11)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: PaperButton(
                  label: attemptUsed
                      ? 'ATTEMPT USED'
                      : "FLY TODAY'S SEED",
                  expand: true,
                  color: attemptUsed
                      ? AppColors.paperWarm
                      : AppColors.accent,
                  textColor: attemptUsed
                      ? AppColors.paperInkSoft
                      : AppColors.paperInk,
                  onPressed: attemptUsed
                      ? null
                      : () => Navigator.of(context).pushNamed(
                            AppRoutes.game,
                            arguments: const GameScreenArgs(
                                mode: GameMode.daily),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackBar extends StatelessWidget {
  const _BackBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.accentAlt,
                  fontSize: 26,
                  letterSpacing: 2,
                )),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paper,
      elevation: 1.2,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PaperIcon(PaperIconData.calendar,
                  size: 20, color: AppColors.gemBlueDeep),
              const SizedBox(width: 8),
              Text('HOW IT WORKS',
                  style: AppTypography.label
                      .copyWith(color: AppColors.paperInk, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: PaperIcon(PaperIconData.glider,
                      size: 12, color: AppColors.accentDeep),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: AppTypography.caption.copyWith(
                        color: AppColors.paperInkSoft,
                        fontSize: 12.5,
                        height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
