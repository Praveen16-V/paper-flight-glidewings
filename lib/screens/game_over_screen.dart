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
                      mode: widget.args.mode,
                    ),
                    const SizedBox(height: 28),
                    if (widget.args.mode == GameMode.daily) ...[
                      _DailyBanner(seed: widget.args.dailySeed),
                      const SizedBox(height: 16),
                    ],
                    if (result != null) _StatsCard(result: result),
                    const SizedBox(height: 28),
                    if (widget.args.mode == GameMode.classic)
                      _HighScoreRow(
                        thisScore: result?.score ?? 0,
                        bestScore: save.highScore,
                      )
                    else
                      Text(
                        result?.isNewHighScore == true
                            ? 'New personal best for this seed!'
                            : 'Your daily best is tracked on the board.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(letterSpacing: 0.5),
                      ),
                    const Spacer(),
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
      ),
    );
  }

  void _onRevive() {
    AdService.instance.showRewarded(
      placement: AdPlacement.revive,
      onRewarded: () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.game);
        }
      },
      onDismissed: () {},
    );
  }

  void _onDoubleCoins() {
    if (_doubleCoinsUsed) return;
    AdService.instance.showRewarded(
      placement: AdPlacement.doubleCoins,
      onRewarded: () async {
        if (mounted && _result != null) {
          setState(() => _doubleCoinsUsed = true);
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
    final Color sheet;
    if (mode == GameMode.daily) {
      title = isNewHighScore ? 'NEW DAILY BEST!' : 'RUN COMPLETE';
      titleColor = isNewHighScore ? AppColors.warning : AppColors.accentAlt;
      sheet = AppColors.paperBlue;
    } else if (isNewHighScore) {
      title = 'NEW BEST!';
      titleColor = AppColors.warning;
      sheet = AppColors.paperGold;
    } else {
      title = 'CRASHED';
      titleColor = AppColors.danger;
      sheet = AppColors.paperRose;
    }
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Folded paper ribbon behind title.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: sheet,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                title,
                style: AppTypography.displayMedium.copyWith(
                  color: titleColor,
                  fontSize: title.length > 12 ? 22 : 30,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          mode == GameMode.daily
              ? "today's seeded flight"
              : 'in ${biome.displayName}',
          style: AppTypography.caption.copyWith(letterSpacing: 1.5),
        ),
      ],
    );
  }
}

class _DailyBanner extends StatelessWidget {
  const _DailyBanner({this.seed});
  final int? seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paperBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PaperIcon(PaperIconData.calendar,
              size: 16, color: AppColors.gemBlueDeep),
          const SizedBox(width: 8),
          Text(
            seed == null ? 'DAILY' : DailySeedService.label(seed!),
            style: AppTypography.label.copyWith(
              color: AppColors.gemBlueDeep,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '•  one attempt per day',
            style: AppTypography.caption
                .copyWith(color: AppColors.paperInkSoft, fontSize: 11.5),
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
    final doubled = result.doubleCoinsApplied;
    return PaperCard(
      color: AppColors.paper,
      elevation: 1.4,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      dogEar: result.isNewHighScore
          ? const DogEar(label: 'BEST', color: AppColors.accent, size: 64)
          : null,
      child: Column(
        children: [
          _StatRow(
            label: 'Score',
            value: result.score,
            highlight: true,
          ),
          Divider(
              color: AppColors.paperInkSoft.withOpacity(0.25), height: 20),
          _StatRow(
            label: 'Distance',
            value: result.distanceMeters,
            suffix: ' m',
          ),
          const SizedBox(height: 10),
          _StatRow(
            label: doubled ? 'Coins  (×2)' : 'Coins',
            value: doubled ? result.coinsCollected * 2 : result.coinsCollected,
            valueColor: doubled ? AppColors.coinGoldDeep : null,
            leading: const CoinChipSized(),
          ),
          const SizedBox(height: 10),
          _StatRow(
            label: 'Near Misses',
            value: result.nearMisses,
          ),
          if (result.wasRevived) ...[
            const SizedBox(height: 10),
            const _CheckRow(label: 'Revived'),
          ],
        ],
      ),
    );
  }
}

/// Inline coin glyph sized to a stat row label.
class CoinChipSized extends StatelessWidget {
  const CoinChipSized({super.key});
  @override
  Widget build(BuildContext context) =>
      PaperIcon(PaperIconData.coin, size: 16, color: AppColors.coinGold);
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueColor,
    this.suffix = '',
    this.leading,
  });
  final String label;
  final num value;
  final bool highlight;
  final Color? valueColor;
  final String suffix;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Text(label,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.paperInkSoft)),
          ],
        ),
        highlight
            ? StatCounter(
                value,
                suffix: suffix,
                style: AppTypography.score.copyWith(
                  color: valueColor ?? AppColors.paperInk,
                  fontSize: 30,
                ),
              )
            : StatCounter(
                value,
                suffix: suffix,
                style: AppTypography.stat.copyWith(
                  color: valueColor ?? AppColors.paperInk,
                  fontSize: 17,
                ),
              ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.paperInkSoft)),
        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
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
      style: AppTypography.caption.copyWith(letterSpacing: 1),
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
        if (_canRevive) ...[
          _AdButton(
            label: 'Watch Ad  →  Revive',
            icon: Icons.play_circle_outline,
            color: AppColors.success,
            onTap: onRevive,
          ),
          const SizedBox(height: 10),
        ],
        if (!isDaily && !doubleCoinsUsed && !adsRemoved) ...[
          _AdButton(
            label: 'Watch Ad  →  2× Coins',
            icon: Icons.monetization_on_outlined,
            color: AppColors.coinGold,
            onTap: onDoubleCoins,
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: PaperButton(
                label: isDaily ? 'Daily Board' : 'Retry',
                icon: Icon(
                  isDaily ? Icons.calendar_today_outlined : Icons.refresh,
                  size: 20,
                ),
                onPressed: onRetry,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PaperButton(
                label: 'Menu',
                icon: const Icon(Icons.home_outlined, size: 20),
                onPressed: onMenu,
                color: AppColors.paperWarm,
                textColor: AppColors.paperInk,
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
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.paperBright,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: _edge(color),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.label.copyWith(color: color, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _edge(Color c) =>
      HSLColor.fromColor(c).withLightness(0.35).toColor();
}
