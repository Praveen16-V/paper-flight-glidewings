import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
import '../models/run_result.dart';
import '../providers/game_session_provider.dart';
import '../providers/save_data_provider.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import 'game_screen.dart';

/// Args passed via route.
class GameOverArgs {
  const GameOverArgs({this.result});
  final RunResult? result;
}

/// Results screen shown after every run.
///
/// Flow (GDD §10 / §11):
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
  bool _reviveUsed = false;
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

  bool _runRecorded = false;

  Future<void> _runPostGameFlow() async {
    // Don't permanently record yet if the player can still revive —
    // recording happens on Retry / Menu / after double-coins / when revive
    // is unavailable.
    final canStillRevive = ref.read(gameSessionProvider).canRevive &&
        ref.read(gameSessionProvider).crashSnapshot != null &&
        !(_result?.wasRevived ?? false);

    if (!canStillRevive) {
      await _recordRunIfNeeded();
    }

    final save = ref.read(saveDataProvider);

    // Log analytics (preview — final record may still be pending).
    if (_result != null && !canStillRevive) {
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

    // Interstitial only after the run is "committed" (no revive pending).
    if (!canStillRevive) {
      await AdService.instance.maybeShowInterstitial(
        totalRuns: save.totalRuns,
        runsSinceLastInterstitial: save.runsSinceLastInterstitial,
        adsRemoved: save.adsRemoved,
        onComplete: () {
          if (mounted) {
            ref.read(saveDataProvider.notifier).resetInterstitialCounter();
          }
        },
      );
    }

    if (mounted) _anim.forward();
  }

  Future<void> _recordRunIfNeeded() async {
    if (_runRecorded || _result == null) return;
    _runRecorded = true;
    final isNew = await ref.read(saveDataProvider.notifier).recordRunResult(
          score: _result!.score,
          distanceMeters: _result!.distanceMeters,
          coinsEarned: _result!.coinsCollected,
          nearMisses: _result!.nearMisses,
        );
    if (isNew && mounted) {
      setState(() {
        _result = _result!.copyWith(isNewHighScore: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final result = _result;
    final sessionCanRevive =
        ref.watch(gameSessionProvider.select((s) => s.canRevive));

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

                  _Header(
                    isNewHighScore: result?.isNewHighScore ?? false,
                    biome: result?.finalBiome ?? Biome.city,
                  ),

                  const SizedBox(height: 28),

                  if (result != null) _StatsCard(result: result),

                  const SizedBox(height: 28),

                  _HighScoreRow(
                    thisScore: result?.score ?? 0,
                    bestScore: save.highScore,
                  ),

                  const Spacer(),

                  _ActionButtons(
                    result: result,
                    adsRemoved: save.adsRemoved,
                    doubleCoinsUsed: _doubleCoinsUsed,
                    canRevive: !_reviveUsed &&
                        sessionCanRevive &&
                        !(result?.wasRevived ?? false),
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
    if (_reviveUsed) return;
    final snap = ref.read(gameSessionProvider).crashSnapshot;
    if (snap == null) return;

    final adsRemoved = ref.read(saveDataProvider).adsRemoved;

    void doRevive() {
      if (!mounted) return;
      setState(() => _reviveUsed = true);
      // Run is NOT recorded yet — continues via snapshot. Final crash records.
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.game,
        arguments: const GameScreenArgs(revive: true),
      );
    }

    // Players who bought Remove Ads get a free revive (goodwill).
    if (adsRemoved) {
      doRevive();
      return;
    }

    AdService.instance.showRewarded(
      placement: AdPlacement.revive,
      onRewarded: doRevive,
      onDismissed: () {},
    );
  }

  void _onDoubleCoins() {
    if (_doubleCoinsUsed || _result == null) return;
    AdService.instance.showRewarded(
      placement: AdPlacement.doubleCoins,
      onRewarded: () async {
        if (mounted && _result != null) {
          // Commit the run first so base coins exist, then double.
          await _recordRunIfNeeded();
          setState(() {
            _doubleCoinsUsed = true;
            _result = _result!.copyWith(doubleCoinsApplied: true);
          });
          await ref
              .read(saveDataProvider.notifier)
              .addCoins(_result!.coinsCollected);
        }
      },
      onDismissed: () {},
    );
  }

  Future<void> _onRetry() async {
    AnalyticsService.instance.logEvent('retry_tapped');
    await _recordRunIfNeeded();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.game,
      arguments: const GameScreenArgs(),
    );
  }

  Future<void> _onMenu() async {
    await _recordRunIfNeeded();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.mainMenu);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isNewHighScore, required this.biome});
  final bool isNewHighScore;
  final Biome biome;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isNewHighScore ? 'NEW BEST!' : 'CRASHED',
          style: TextStyle(
            color: isNewHighScore ? AppColors.warning : AppColors.danger,
            fontSize: isNewHighScore ? 30 : 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'in ${biome.displayName}',
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
                ? '${result.coinsCollected * 2} (x2!)'
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
              value: 'Yes',
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
            color: valueColor ?? AppColors.textLight,
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
    required this.canRevive,
    required this.onRevive,
    required this.onDoubleCoins,
    required this.onRetry,
    required this.onMenu,
  });

  final RunResult? result;
  final bool adsRemoved;
  final bool doubleCoinsUsed;
  final bool canRevive;
  final VoidCallback onRevive;
  final VoidCallback onDoubleCoins;
  final Future<void> Function() onRetry;
  final Future<void> Function() onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Revive — always available once if not already used (even with ads removed,
        // players who bought remove-ads still get the revive UX via a free grant).
        if (canRevive) ...[
          _AdButton(
            label: adsRemoved ? 'Revive' : 'Watch Ad → Revive',
            icon: Icons.play_circle_outline,
            color: AppColors.success,
            onTap: onRevive,
          ),
          const SizedBox(height: 10),
        ],

        // Double coins — rewarded only when ads present.
        if (!doubleCoinsUsed && !adsRemoved) ...[
          _AdButton(
            label: 'Watch Ad → 2× Coins',
            icon: Icons.monetization_on_outlined,
            color: AppColors.coinGold,
            onTap: onDoubleCoins,
          ),
          const SizedBox(height: 16),
        ],

        // Primary actions.
        Row(
          children: [
            Expanded(
              child: _PrimaryButton(
                label: 'Retry',
                icon: Icons.refresh,
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
          border:
              isPrimary ? null : Border.all(color: AppColors.divider),
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
