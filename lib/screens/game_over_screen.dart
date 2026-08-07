import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
import '../models/run_result.dart';
import '../providers/save_data_provider.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_seed_service.dart';

/// Args passed via route.
class GameOverArgs {
  const GameOverArgs({
    this.result,
    this.mode = GameMode.classic,
    this.dailySeed,
  });
  final RunResult? result;

  /// Which mode this run belonged to (Task 8 — daily behaves differently).
  final GameMode mode;

  /// Today's daily seed when [mode] is [GameMode.daily].
  final int? dailySeed;
}

/// Results screen shown after every run.
///
/// Flow:
///   1. Maybe show interstitial (respects honeymoon + frequency cap).
///   2. Display score, distance, coins, near-misses.
///   3. New-high-score celebration if applicable.
///   4. Action row:
///        [Watch Ad → Revive] (once per run, if not already revived)
///        [Watch Ad → 2× Coins]
///        [Retry] [Menu]
class GameOverScreen extends ConsumerStatefulWidget {
  const GameOverScreen({super.key, required this.args});
  final GameOverArgs args;

  @override
  ConsumerState<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends ConsumerState<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  bool _doubleCoinsUsed = false;
  bool _interstitialDone = false;
  RunResult? _result;

  @override
  void initState() {
    super.initState();
    _result = widget.args.result;

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _runPostGameFlow();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _runPostGameFlow() async {
    final save = ref.read(saveDataProvider);

    // Log analytics.
    if (_result != null) {
      await AnalyticsService.instance.logRunCompleted(
        score: _result!.score,
        distanceMeters: _result!.distanceMeters,
        coinsCollected: _result!.coinsCollected,
        nearMisses: _result!.nearMisses,
        biome: _result!.finalBiome.name,
        wasRevived: _result!.wasRevived,
      );
      if (_result!.isNewHighScore) {
        await AnalyticsService.instance.logNewHighScore(_result!.score);
      }
    }

    // Maybe show interstitial — classic runs only (Task 8: the daily seeded
    // flight is a clean, ad-free competitive run).
    if (widget.args.mode == GameMode.classic) {
      await AdService.instance.maybeShowInterstitial(
        totalRuns: save.totalRuns,
        runsSinceLastInterstitial: save.runsSinceLastInterstitial,
        adsRemoved: save.adsRemoved,
        onComplete: () {
          if (mounted) {
            setState(() => _interstitialDone = true);
            ref.read(saveDataProvider.notifier).resetInterstitialCounter();
          }
        },
      );
    }

    _anim.forward();
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // ── Header ────────────────────────────────────────────────
                  _Header(
                    isNewHighScore: result?.isNewHighScore ?? false,
                    biome: result?.finalBiome ?? Biome.city,
                    mode: widget.args.mode,
                  ),

                  const SizedBox(height: 28),

                  // ── Daily seeded banner (Task 8) ─────────────────────────
                  if (widget.args.mode == GameMode.daily) ...[
                    _DailyBanner(seed: widget.args.dailySeed),
                    const SizedBox(height: 16),
                  ],

                  // ── Stats card ────────────────────────────────────────────
                  if (result != null) _StatsCard(result: result),

                  const SizedBox(height: 28),

                  // ── High score comparison ─────────────────────────────────
                  if (widget.args.mode == GameMode.classic)
                    _HighScoreRow(
                      thisScore: result?.score ?? 0,
                      bestScore: save.highScore,
                    )
                  else
                    Text(
                      result?.isNewHighScore == true
                          ? '🏆 New personal best for this seed!'
                          : 'Your daily best is tracked on the board.',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),

                  const Spacer(),

                  // ── Action buttons ────────────────────────────────────────
                  _ActionButtons(
                    result: result,
                    adsRemoved: save.adsRemoved,
                    doubleCoinsUsed: _doubleCoinsUsed,
                    isDaily: widget.args.mode == GameMode.daily,
                    onRevive: _onRevive,
                    onDoubleCoins: _onDoubleCoins,
                    onRetry: _onRetry,
                    onMenu: _onMenu,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onRevive() {
    AdService.instance.showRewarded(
      placement: AdPlacement.revive,
      onRewarded: () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.game);
          // The game screen creates a new PaperFlightGame; revive is handled
          // by checking canRevive flag in gameSessionProvider on re-entry.
          // In a full build: pass a revive flag through the route args so the
          // GameScreen calls game.revive() instead of game.startRun().
        }
      },
      onDismissed: () {
        // Player closed ad without watching — do nothing.
      },
    );
  }

  void _onDoubleCoins() {
    if (_doubleCoinsUsed) return;
    AdService.instance.showRewarded(
      placement: AdPlacement.doubleCoins,
      onRewarded: () async {
        if (mounted && _result != null) {
          setState(() => _doubleCoinsUsed = true);
          // Award the extra coins (the original coins were already saved in
          // recordRunResult; we add the bonus on top).
          await ref
              .read(saveDataProvider.notifier)
              .addCoins(_result!.coinsCollected);
        }
      },
      onDismissed: () {},
    );
  }

  void _onRetry() {
    AnalyticsService.instance.logEvent('retry_tapped');
    if (widget.args.mode == GameMode.daily) {
      // One attempt per day — take the player back to the daily board.
      Navigator.of(context).pushReplacementNamed(AppRoutes.dailyFlight);
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.game);
  }

  void _onMenu() {
    if (widget.args.mode == GameMode.daily) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dailyFlight);
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.mainMenu);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.isNewHighScore,
    required this.biome,
    this.mode = GameMode.classic,
  });
  final bool isNewHighScore;
  final Biome biome;
  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final String title;
    final Color titleColor;
    if (mode == GameMode.daily) {
      title = isNewHighScore ? '🏆 NEW DAILY BEST!' : 'RUN COMPLETE';
      titleColor =
          isNewHighScore ? AppColors.warning : AppColors.accentAlt;
    } else if (isNewHighScore) {
      title = '🏆 NEW BEST!';
      titleColor = AppColors.warning;
    } else {
      title = 'CRASHED';
      titleColor = AppColors.danger;
    }
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: title.length > 12 ? 22 : 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          mode == GameMode.daily
              ? 'today\'s seeded flight'
              : 'in ${biome.displayName}',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Daily seeded flight banner — seed + single-attempt note.
class _DailyBanner extends StatelessWidget {
  const _DailyBanner({this.seed});
  final int? seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentAlt.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined,
              color: AppColors.accentAlt, size: 15),
          const SizedBox(width: 8),
          Text(
            seed == null ? 'DAILY' : DailySeedService.label(seed!),
            style: const TextStyle(
              color: AppColors.accentAlt,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '•  one attempt per day',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.result});
  final RunResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _StatRow(
            label: 'Score',
            value: _fmt(result.score),
            highlight: true,
          ),
          const Divider(color: AppColors.divider, height: 20),
          _StatRow(
            label: 'Distance',
            value: '${result.distanceMeters.toStringAsFixed(0)} m',
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: 'Coins',
            value: result.doubleCoinsApplied
                ? '${result.coinsCollected * 2} (×2!)'
                : '${result.coinsCollected}',
            valueColor:
                result.doubleCoinsApplied ? AppColors.coinGold : null,
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: 'Near Misses',
            value: '${result.nearMisses}',
          ),
          if (result.wasRevived) ...[
            const SizedBox(height: 8),
            const _StatRow(
              label: 'Revived',
              value: '✓',
              valueColor: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool highlight;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ??
                (highlight ? AppColors.textLight : AppColors.textLight),
            fontSize: highlight ? 28 : 16,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HighScoreRow extends StatelessWidget {
  const _HighScoreRow({required this.thisScore, required this.bestScore});
  final int thisScore;
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Best: ${_fmt(bestScore)}',
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        letterSpacing: 1,
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.result,
    required this.adsRemoved,
    required this.doubleCoinsUsed,
    this.isDaily = false,
    required this.onRevive,
    required this.onDoubleCoins,
    required this.onRetry,
    required this.onMenu,
  });

  final RunResult? result;
  final bool adsRemoved;
  final bool doubleCoinsUsed;

  /// Daily seeded flights have no revive and no coin doubling — one clean
  /// attempt, the leaderboard is the reward.
  final bool isDaily;
  final VoidCallback onRevive;
  final VoidCallback onDoubleCoins;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  bool get _canRevive =>
      !isDaily && result != null && !result!.wasRevived && !adsRemoved;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Revive row — shown if not already revived and ads available.
        if (_canRevive) ...[
          _AdButton(
            label: 'Watch Ad → Revive',
            icon: Icons.play_circle_outline,
            color: AppColors.success,
            onTap: onRevive,
          ),
          const SizedBox(height: 10),
        ],

        // Double coins — shown once per run (classic only).
        if (!isDaily && !doubleCoinsUsed && !adsRemoved) ...[
          _AdButton(
            label: doubleCoinsUsed
                ? '2× Coins — Claimed!'
                : 'Watch Ad → 2× Coins',
            icon: Icons.monetization_on_outlined,
            color: AppColors.coinGold,
            onTap: doubleCoinsUsed ? null : onDoubleCoins,
          ),
          const SizedBox(height: 16),
        ],

        // Primary actions.
        Row(
          children: [
            Expanded(
              child: _PrimaryButton(
                label: isDaily ? 'Daily Board' : 'Retry',
                icon: isDaily ? Icons.calendar_today_outlined : Icons.refresh,
                onTap: onRetry,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: 'Menu',
                icon: Icons.home_outlined,
                onTap: onMenu,
                isPrimary: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdButton extends StatelessWidget {
  const _AdButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap != null ? 1.0 : 0.5,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFFF5A623), Color(0xFFFF6B35)],
                )
              : null,
          color: isPrimary ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : AppColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
