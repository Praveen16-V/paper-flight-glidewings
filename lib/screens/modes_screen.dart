import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_effects.dart';
import '../core/widgets/paper_icons.dart';
import '../models/trial_definition.dart';
import '../providers/save_data_provider.dart';
import '../services/daily_seed_service.dart';
import 'game_screen.dart';

/// Game Modes hub — four ways to fly, presented as folded paper sheets.
class ModesScreen extends ConsumerStatefulWidget {
  const ModesScreen({super.key});

  @override
  ConsumerState<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends ConsumerState<ModesScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Live update every second for the Daily Seeded countdown clock.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _timeToReset {
    final now = DateTime.now();
    return DailySeedService.nextResetUtc(now).difference(now.toUtc());
  }

  @override
  Widget build(BuildContext context) {
    final saveData = ref.watch(saveDataProvider);

    // Compute total stars earned across all Precision Trials
    final earnedStars = TrialPool.all.fold(
      0,
      (sum, trial) =>
          sum + ref.read(saveDataProvider.notifier).trialBestStars(trial.id),
    );
    const totalTrialStars = 18;

    // Time to daily reset
    final reset = _timeToReset;
    final hh = reset.inHours.toString().padLeft(2, '0');
    final mm = (reset.inMinutes % 60).toString().padLeft(2, '0');
    final countdownText = 'Reset in ${hh}h ${mm}m';

    // Today's seeded wind condition
    final todaysWind =
        DailySeedService.windLabel(DailySeedService.seedForNow());

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
              _HeaderBar(),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── Classic Mode ──────────────────────────────────────
                    _ClassicModeCard(
                      highScore: saveData.highScore,
                      onTap: () => _onModeTap(context, GameMode.classic),
                    ),
                    const SizedBox(height: 16),

                    // ── Zen Mode ──────────────────────────────────────────
                    _ZenModeCard(
                      onTap: () => _onModeTap(context, GameMode.zen),
                    ),
                    const SizedBox(height: 16),

                    // ── Daily Seeded Mode ─────────────────────────────────
                    _DailyModeCard(
                      countdownText: countdownText,
                      windLabel: todaysWind,
                      onTap: () => _onModeTap(context, GameMode.daily),
                    ),
                    const SizedBox(height: 16),

                    // ── Precision Trials Mode ─────────────────────────────
                    _TrialModeCard(
                      earnedStars: earnedStars,
                      totalStars: totalTrialStars,
                      onTap: () => _onModeTap(context, GameMode.trial),
                    ),
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
}

class _HeaderBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'GAME MODES',
                  textAlign: TextAlign.center,
                  style: AppTypography.displayMedium.copyWith(
                    fontSize: 26,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Four ways to fly', style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ClassicModeCard extends StatelessWidget {
  const _ClassicModeCard({
    required this.highScore,
    required this.onTap,
  });

  final int highScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accent;
    const mode = GameMode.classic;

    return PaperCard(
      onTap: onTap,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF8EA),
          Color(0xFFFDE8C0),
        ],
      ),
      elevation: 1.2,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Medallion(icon: mode.paperIcon, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.displayName,
                      style: AppTypography.title.copyWith(
                        color: _edgeOf(accent),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mode.tagline,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.paperInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Orange Ribbon Badge
              _OrangeRibbonBadge(highScore: highScore),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrangeRibbonBadge extends StatelessWidget {
  const _OrangeRibbonBadge({required this.highScore});
  final int highScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFE65100)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40E65100),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            'HIGH SCORE: $highScore',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZenModeCard extends StatelessWidget {
  const _ZenModeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.success;
    const mode = GameMode.zen;

    return PaperCard(
      onTap: onTap,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF1F9F3),
          Color(0xFFDFF2E2),
        ],
      ),
      borderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF81C784),
          Color(0xFF4DB6AC),
          Color(0xFF64B5F6),
        ],
      ),
      borderWidth: 2.0,
      elevation: 1.2,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Medallion(icon: mode.paperIcon, accent: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      mode.displayName,
                      style: AppTypography.title.copyWith(
                        color: _edgeOf(accent),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Calm "NO CRASHES" pill badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.spa_rounded,
                              size: 12, color: AppColors.success),
                          const SizedBox(width: 3),
                          Text(
                            'NO CRASHES',
                            style: AppTypography.caption.copyWith(
                              color: const Color(0xFF2E7D32),
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  mode.tagline,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.paperInkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: AppColors.paperInkSoft, size: 24),
        ],
      ),
    );
  }
}

class _DailyModeCard extends StatelessWidget {
  const _DailyModeCard({
    required this.countdownText,
    required this.windLabel,
    required this.onTap,
  });

  final String countdownText;
  final String windLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentAlt;
    const mode = GameMode.daily;

    return PaperCard(
      onTap: onTap,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFEBF5FB),
          Color(0xFFD6EAF8),
        ],
      ),
      elevation: 1.2,
      padding: const EdgeInsets.all(16),
      dogEar: const DogEar(label: 'TODAY', color: accent, size: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Medallion(icon: mode.paperIcon, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mode.displayName,
                          style: AppTypography.title.copyWith(
                            color: _edgeOf(accent),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Live countdown clock badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.gemBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.gemBlueDeep.withOpacity(0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 12, color: AppColors.gemBlueDeep),
                              const SizedBox(width: 3),
                              Text(
                                countdownText,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.gemBlueDeep,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mode.tagline,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.paperInkSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Today's seeded wind label directly on the card
                    Row(
                      children: [
                        Icon(Icons.air_rounded,
                            size: 14,
                            color: AppColors.gemBlueDeep.withOpacity(0.85)),
                        const SizedBox(width: 4),
                        Text(
                          'Today\'s Wind: $windLabel',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.paperInkSoft,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.paperInkSoft, size: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrialModeCard extends StatelessWidget {
  const _TrialModeCard({
    required this.earnedStars,
    required this.totalStars,
    required this.onTap,
  });

  final int earnedStars;
  final int totalStars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.danger;
    const mode = GameMode.trial;

    return PaperCard(
      onTap: onTap,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFDF0ED),
          Color(0xFFFADBD8),
        ],
      ),
      elevation: 1.2,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Medallion(icon: mode.paperIcon, accent: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.displayName,
                  style: AppTypography.title.copyWith(
                    color: _edgeOf(accent),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mode.tagline,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.paperInkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Star-progress indicator (X / 18 ★) on the right side of the card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.85),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$earnedStars / $totalStars ★',
                  style: AppTypography.statSmall.copyWith(
                    color: AppColors.paperInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: AppColors.paperInkSoft, size: 24),
        ],
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, required this.accent});
  final PaperIconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
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
          ...PaperShadows.stack(color: AppColors.paperInk, elevation: 0.5),
        ],
      ),
      child: Center(
        child: PaperIcon(icon, size: 28, color: Colors.white),
      ),
    );
  }
}

Color _edgeOf(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
      .toColor();
}
