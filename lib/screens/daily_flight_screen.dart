import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
import '../providers/save_data_provider.dart';
import '../services/daily_leaderboard_service.dart';
import '../services/daily_seed_service.dart';
import 'game_screen.dart';

/// Pre-flight hub for the Daily Seeded Flight (Task 8).
///
/// Every player on Earth faces the identical wind, obstacles and coins for
/// today's seed (UTC-based). One attempt per day — quitting mid-run counts.
/// The award is a leaderboard rank; the run never touches the coin economy.
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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              DailySeedService.label(_seed),
              style: const TextStyle(
                color: AppColors.accentAlt,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'TODAY\'S SEEDED FLIGHT',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // ── Reset countdown ──────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule,
                      color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Next seed in  $hh:$mm:$ss',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
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
                  // ── Rules card ─────────────────────────────────────────
                  _InfoCard(
                    icon: '🌍',
                    lines: const [
                      'The wind, obstacles and coins are generated from today\'s seed — identical for every player worldwide.',
                      'One attempt per day (UTC). Quitting mid-run counts as your attempt.',
                      'Award: your place on the daily board. This run doesn\'t bank coins or progress challenges.',
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Attempt status ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: attemptUsed
                          ? AppColors.danger.withOpacity(0.12)
                          : AppColors.success.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: attemptUsed
                            ? AppColors.danger.withOpacity(0.5)
                            : AppColors.success.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          attemptUsed ? '✅' : '⏳',
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            attemptUsed
                                ? 'Today\'s attempt used. Come back tomorrow for a fresh seed!'
                                : 'Attempt available — make it count!',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Personal best for this seed ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            color: AppColors.warning, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'YOUR BEST FOR THIS SEED',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _best == null
                                    ? '— not flown yet —'
                                    : '${_best!.score} pts  •  ${_best!.distanceMeters.toStringAsFixed(0)} m',
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Recent flights ─────────────────────────────────────
                  if (_recent.isNotEmpty) ...[
                    const Text(
                      'RECENT FLIGHTS',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: _recent.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Text(
                                  DailySeedService.label(
                                      DailySeedService.seedForDate(e.dateUtc)),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${e.score} pts',
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${e.distanceMeters.toStringAsFixed(0)} m',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
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

            // ── Play button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: attemptUsed
                        ? AppColors.divider
                        : AppColors.accent,
                    disabledBackgroundColor: AppColors.divider,
                  ),
                  onPressed: attemptUsed
                      ? null
                      : () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.game,
                            arguments: const GameScreenArgs(
                                mode: GameMode.daily),
                          );
                        },
                  child: Text(attemptUsed ? 'ATTEMPT USED' : 'FLY TODAY\'S SEED'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.lines});
  final String icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'HOW IT WORKS',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text('•  ',
                      style: TextStyle(color: AppColors.accentAlt)),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
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
