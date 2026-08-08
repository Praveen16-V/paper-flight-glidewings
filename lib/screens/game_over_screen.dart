import 'dart:math' as math;

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

/// Results screen shown after every run — now as a stamped Flight Log receipt.
class GameOverScreen extends ConsumerStatefulWidget {
  const GameOverScreen({super.key, required this.args});
  final GameOverArgs args;

  @override
  ConsumerState<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends ConsumerState<GameOverScreen>
    with TickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  // stamp controller
  late AnimationController _stampCtrl;
  late Animation<double> _stampScale;
  late Animation<double> _stampRotate;

  bool _doubleCoinsUsed = false;
  bool _interstitialDone = false;
  RunResult? _result;

  @override
  void initState() {
    super.initState();
    _result = widget.args.result;

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _stampCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _stampScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.22).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 40),
    ]).animate(_stampCtrl);
    _stampRotate = Tween<double>(begin: -0.18, end: -0.12).animate(CurvedAnimation(parent: _stampCtrl, curve: Curves.easeOutCubic));

    _runPostGameFlow();
  }

  @override
  void dispose() {
    _anim.dispose();
    _stampCtrl.dispose();
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
    // stamp fires after card settles
    Future.delayed(const Duration(milliseconds: 620), () {
      if (mounted && (_result?.isNewHighScore ?? false)) {
        _stampCtrl.forward();
      }
    });
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 16,
                          maxWidth: 500,
                        ),
                        child: Column(
                        children: [
                          const SizedBox(height: 18),
                          _Header(
                            isNewHighScore: result?.isNewHighScore ?? false,
                            biome: result?.finalBiome ?? Biome.city,
                            mode: widget.args.mode,
                          ),
                          const SizedBox(height: 16),
                          if (widget.args.mode == GameMode.daily) ...[
                            _DailyBanner(seed: widget.args.dailySeed),
                            const SizedBox(height: 12),
                          ],
                          if (result != null)
                            _FlightLogReceiptCard(
                              result: result,
                              mode: widget.args.mode,
                              dailySeed: widget.args.dailySeed,
                              stampScale: _stampScale,
                              stampRotate: _stampRotate,
                              bestScore: save.highScore,
                            ),
                          if (result == null) ...[
                            const SizedBox(height: 40),
                            Text('No flight data',
                                style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                          ],
                          const SizedBox(height: 18),
                          if (widget.args.mode == GameMode.daily)
                            Text(
                              result?.isNewHighScore == true
                                  ? 'New personal best for this seed!'
                                  : 'Your daily best is tracked on the board.',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(letterSpacing: 0.5),
                            )
                          else
                            // classic best row is already inside receipt; keep spacer for rhythm
                            const SizedBox.shrink(),
                          const SizedBox(height: 22),
                          _ActionHierarchy(
                            result: result,
                            adsRemoved: save.adsRemoved,
                            doubleCoinsUsed: _doubleCoinsUsed,
                            isDaily: widget.args.mode == GameMode.daily,
                            onRevive: _onRevive,
                            onDoubleCoins: _onDoubleCoins,
                            onRetry: _onRetry,
                            onMenu: _onMenu,
                          ),
                          const SizedBox(height: 20),
                          Text('PAPER FLIGHT  •  FLIGHT LOG ARCHIVE',
                              style: AppTypography.overline.copyWith(
                                  color: Colors.white.withOpacity(0.22), fontSize: 9, letterSpacing: 1.4)),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                );
                },
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
          await ref.read(saveDataProvider.notifier).addCoins(_result!.coinsCollected);
          // reflect doubled in local result
          setState(() {
            _result = RunResult(
              score: _result!.score,
              distanceMeters: _result!.distanceMeters,
              coinsCollected: _result!.coinsCollected,
              nearMisses: _result!.nearMisses,
              finalBiome: _result!.finalBiome,
              isNewHighScore: _result!.isNewHighScore,
              wasRevived: _result!.wasRevived,
              doubleCoinsApplied: true,
            );
          });
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

// ── Header ──────────────────────────────────────────────────────────────────

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: sheet,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black38, offset: Offset(0, 4), blurRadius: 0),
            ],
          ),
          child: Text(
            title,
            style: AppTypography.displayMedium.copyWith(
              color: titleColor,
              fontSize: title.length > 12 ? 22 : 28,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          mode == GameMode.daily ? "today's seeded flight" : 'in ${biome.displayName}',
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
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 0)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PaperIcon(PaperIconData.calendar, size: 16, color: AppColors.gemBlueDeep),
          const SizedBox(width: 8),
          Text(
            seed == null ? 'DAILY' : DailySeedService.label(seed!),
            style: AppTypography.label.copyWith(color: AppColors.gemBlueDeep, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(width: 8),
          Text('•  one attempt per day', style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 11.5)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Flight Log Receipt — stamped paper with perforated/dashed lines + count-ups
// ═════════════════════════════════════════════════════════════════════════════

class _FlightLogReceiptCard extends StatelessWidget {
  const _FlightLogReceiptCard({
    required this.result,
    required this.mode,
    this.dailySeed,
    required this.stampScale,
    required this.stampRotate,
    required this.bestScore,
  });

  final RunResult result;
  final GameMode mode;
  final int? dailySeed;
  final Animation<double> stampScale;
  final Animation<double> stampRotate;
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    final flightNo = _flightNumber(result);
    final dateStr = _dateStr();
    final doubled = result.doubleCoinsApplied;
    final coinsDisplay = doubled ? result.coinsCollected * 2 : result.coinsCollected;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // shadow under paper
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 8)),
              BoxShadow(color: AppColors.paperInk.withOpacity(0.12), blurRadius: 0, offset: const Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: AppColors.paper,
              child: Stack(
                children: [
                  // paper grain texture faint
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.055,
                        child: CustomPaint(painter: _ReceiptGrainPainter()),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // top airline band
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        decoration: BoxDecoration(
                          color: AppColors.paperWarm,
                          border: Border(bottom: BorderSide(color: AppColors.paperInkSoft.withOpacity(0.14), width: 1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.paperInk,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('FLIGHT LOG',
                                  style: AppTypography.overline.copyWith(color: Colors.white, fontSize: 9, letterSpacing: 1.2)),
                            ),
                            const SizedBox(width: 8),
                            Text('PAPER AIR  •  NO. $flightNo',
                                style: AppTypography.overline.copyWith(color: AppColors.paperInkSoft, fontSize: 9, letterSpacing: 1.0)),
                            const Spacer(),
                            Icon(Icons.flight, size: 14, color: AppColors.paperInkSoft.withOpacity(0.65)),
                          ],
                        ),
                      ),

                      // meta row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Row(
                          children: [
                            Text(dateStr, style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 10.5, letterSpacing: 0.3)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundDeep.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.paperInkSoft.withOpacity(0.18)),
                              ),
                              child: Text(result.finalBiome.displayName.toUpperCase(),
                                  style: AppTypography.overline.copyWith(color: AppColors.paperInkSoft, fontSize: 8, letterSpacing: 0.9)),
                            ),
                          ],
                        ),
                      ),

                      // dashed separator
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: _DashedLine(color: Color(0xFF6B6450), opacity: 0.22, dashWidth: 6, gapWidth: 4),
                      ),

                      // SCORE large — stamped area
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SCORE',
                                    style: AppTypography.overline.copyWith(color: AppColors.paperInkSoft, fontSize: 10, letterSpacing: 1.4)),
                                const SizedBox(height: 2),
                                // keep stamp area clear on right
                                SizedBox(
                                  width: 170,
                                  child: _AnimatedCountUp(
                                    value: result.score,
                                    style: AppTypography.score.copyWith(color: AppColors.paperInk, fontSize: 32, height: 1.0),
                                    duration: const Duration(milliseconds: 900),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // small score badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundDeep,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events_rounded, size: 13, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text('BEST ${_fmt(bestScore)}',
                                      style: TextStyle(
                                          fontFamily: AppTypography.mono,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white.withOpacity(0.92))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // perforated line (dotted + circles)
                      const _PerforatedDivider(),

                      // Stats rows with animated count-ups
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          children: [
                            _ReceiptStatRow(
                              icon: Icons.straighten_rounded,
                              label: 'Distance',
                              value: result.distanceMeters,
                              suffix: ' m',
                              isDouble: false,
                              accent: AppColors.accentAlt,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _DashedLine(color: Color(0xFF6B6450), opacity: 0.14, dashWidth: 4, gapWidth: 6),
                            ),
                            _ReceiptStatRow(
                              icon: Icons.monetization_on_rounded,
                              label: doubled ? 'Coins  (×2 bonus)' : 'Coins',
                              value: coinsDisplay.toDouble(),
                              suffix: '',
                              isDouble: false,
                              accent: AppColors.coinGoldDeep,
                              leading: PaperIcon(PaperIconData.coin, size: 16, color: AppColors.coinGold),
                              highlight: doubled,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _DashedLine(color: Color(0xFF6B6450), opacity: 0.14, dashWidth: 4, gapWidth: 6),
                            ),
                            _ReceiptStatRow(
                              icon: Icons.bolt_rounded,
                              label: 'Near Misses',
                              value: result.nearMisses.toDouble(),
                              suffix: '',
                              isDouble: false,
                              accent: AppColors.warning,
                            ),
                            if (result.wasRevived) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: _DashedLine(color: Color(0xFF6B6450), opacity: 0.14, dashWidth: 4, gapWidth: 6),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.success.withOpacity(0.28)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.health_and_safety_rounded, size: 13, color: AppColors.success),
                                        const SizedBox(width: 4),
                                        Text('REVIVED',
                                            style: AppTypography.overline.copyWith(color: AppColors.success, fontSize: 9, letterSpacing: 1.0)),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const _PerforatedDivider(),

                      // footer tape — barcode like line + thank you
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: Row(
                          children: [
                            // barcode lines
                            SizedBox(
                              width: 86,
                              height: 22,
                              child: CustomPaint(painter: _BarcodePainter()),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('THANK YOU FOR FLYING PAPER AIR',
                                      style: AppTypography.overline.copyWith(color: AppColors.paperInkSoft, fontSize: 8, letterSpacing: 1.0)),
                                  const SizedBox(height: 2),
                                  Text('Keep this receipt  •  FLIGHT $flightNo',
                                      style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft.withOpacity(0.65), fontSize: 9)),
                                ],
                              ),
                            ),
                            Icon(Icons.content_cut_rounded, size: 14, color: AppColors.paperInkSoft.withOpacity(0.35)),
                          ],
                        ),
                      ),

                      // bottom zigzag tear edge (visual only, inside card)
                      SizedBox(height: 7, child: CustomPaint(painter: _ZigZagPainter(), size: const Size.fromHeight(7))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // top perforation punch holes — appear as cutouts
        Positioned(
          top: -1,
          left: 10,
          right: 10,
          child: _PunchHolesRow(color: AppColors.backgroundDeep),
        ),

        // NEW BEST stamp — animated, clear of punch holes
        if (result.isNewHighScore)
          Positioned(
            top: 76,
            right: 10,
            child: AnimatedBuilder(
              animation: stampScale,
              builder: (context, child) {
                return Transform.rotate(
                  angle: stampRotate.value,
                  child: Transform.scale(
                    scale: stampScale.value,
                    child: Opacity(
                      opacity: (stampScale.value).clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: _FlightStamp(label: mode == GameMode.daily ? 'DAILY BEST!' : 'NEW BEST!'),
            ),
          ),
      ],
    );
  }

  String _flightNumber(RunResult r) {
    // deterministic but looks like ticket number
    final n = (r.score * 37 + r.distanceMeters.toInt() * 13) % 10000;
    return n.toString().padLeft(4, '0');
  }

  String _dateStr() {
    final now = DateTime.now();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final m = months[now.month - 1];
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$m $d  •  $h:$min';
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _FlightStamp extends StatelessWidget {
  const _FlightStamp({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE53935), width: 2.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE53935).withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 13, color: Color(0xFFE53935)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontFamily: AppTypography.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.2,
                      color: const Color(0xFFE53935))),
              const SizedBox(width: 4),
              const Icon(Icons.stars_rounded, size: 13, color: Color(0xFFE53935)),
            ],
          ),
          const SizedBox(height: 2),
          Container(height: 1.2, width: 110, color: const Color(0xFFE53935).withOpacity(0.55)),
          const SizedBox(height: 2),
          Text('FLIGHT RECORD  •  CERTIFIED',
              style: AppTypography.overline.copyWith(color: const Color(0xFFE53935), fontSize: 7, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}

class _ReceiptStatRow extends StatelessWidget {
  const _ReceiptStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
    this.leading,
    this.accent = AppColors.accent,
    this.isDouble = true,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final double value;
  final String suffix;
  final Widget? leading;
  final Color accent;
  final bool isDouble;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withOpacity(0.22)),
          ),
          child: Icon(icon, size: 15, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.paperInkSoft, fontSize: 13)),
            ],
          ),
        ),
        _AnimatedCountUp(
          value: value,
          suffix: suffix,
          isDouble: isDouble,
          style: AppTypography.stat.copyWith(color: highlight ? AppColors.coinGoldDeep : AppColors.paperInk, fontSize: 17),
          duration: const Duration(milliseconds: 850),
        ),
      ],
    );
  }
}

class _AnimatedCountUp extends StatelessWidget {
  const _AnimatedCountUp({
    required this.value,
    required this.style,
    this.suffix = '',
    this.isDouble = true,
    this.duration = const Duration(milliseconds: 800),
  });
  final num value;
  final TextStyle style;
  final String suffix;
  final bool isDouble;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.toDouble();
    // For int-like values animate as int, for double keep one decimal
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final txt = isDouble ? v.toStringAsFixed(1) : v.toInt().toString();
        // add comma grouping for ints
        final display = _format(v, isDouble);
        return Text('$display$suffix',
            style: style.copyWith(fontFamily: AppTypography.mono, fontFeatures: const [FontFeature.tabularFigures()]));
      },
    );
  }

  String _format(double v, bool isDbl) {
    if (isDbl) {
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(1);
    }
    final n = v.toInt();
    // comma grouping
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buf.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color, this.opacity = 0.2, this.dashWidth = 5, this.gapWidth = 5, this.thickness = 1});
  final Color color;
  final double opacity;
  final double dashWidth;
  final double gapWidth;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(color: color.withOpacity(opacity), dashWidth: dashWidth, gapWidth: gapWidth, thickness: thickness),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color, required this.dashWidth, required this.gapWidth, required this.thickness});
  final Color color;
  final double dashWidth;
  final double gapWidth;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thickness..strokeCap = StrokeCap.butt;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dashWidth).clamp(0, size.width), y), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) =>
      old.color != color || old.dashWidth != dashWidth || old.gapWidth != gapWidth;
}

class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.paperWarm, shape: BoxShape.circle, border: Border.all(color: AppColors.paperInkSoft.withOpacity(0.25)))),
          const SizedBox(width: 6),
          const Expanded(child: _DashedLine(color: Color(0xFF6B6450), opacity: 0.18, dashWidth: 5, gapWidth: 5)),
          const SizedBox(width: 6),
          Icon(Icons.flight_takeoff_rounded, size: 12, color: AppColors.paperInkSoft.withOpacity(0.35)),
          const SizedBox(width: 6),
          const Expanded(child: _DashedLine(color: Color(0xFF6B6450), opacity: 0.18, dashWidth: 5, gapWidth: 5)),
          const SizedBox(width: 6),
          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.paperWarm, shape: BoxShape.circle, border: Border.all(color: AppColors.paperInkSoft.withOpacity(0.25)))),
        ],
      ),
    );
  }
}

class _PunchHolesRow extends StatelessWidget {
  const _PunchHolesRow({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(20, (_) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 2, offset: const Offset(0, 1))]),
        );
      }),
    );
  }
}

class _ZigZagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.paper.withOpacity(1)..style = PaintingStyle.fill;
    final path = Path()..moveTo(0, 0);
    const zig = 10.0;
    final count = (size.width / zig).ceil();
    for (var i = 0; i < count; i++) {
      final x = i * zig;
      final isUp = i.isEven;
      path.lineTo(x + zig / 2, isUp ? size.height : 0);
    }
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    // we want a zigzag cut at top edge: draw white triangles overlay blending? Instead draw zig line
    // Simpler: draw zigzag path filled with backgroundDeep to look torn
    // For now just draw paper color with zig top
    // Draw base rect then overlay zig triangles with background color
    canvas.drawPath(path, paint);
    // draw zig line stroke
    final linePaint = Paint()..color = AppColors.paperInkSoft.withOpacity(0.10)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    final linePath = Path()..moveTo(0, 0);
    for (var i = 0; i < count; i++) {
      final x = i * zig;
      linePath.lineTo(x + zig / 2, i.isEven ? size.height : 0);
    }
    linePath.lineTo(size.width, 0);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(99);
    final paint = Paint()..color = AppColors.paperInk.withOpacity(0.85)..strokeWidth = 1.2..strokeCap = StrokeCap.butt;
    double x = 2;
    while (x < size.width - 2) {
      final w = rnd.nextBool() ? 1.2 : 2.4;
      final h = rnd.nextDouble() * 6 + 12;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint..strokeWidth = w);
      x += w + rnd.nextDouble() * 2 + 1;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ReceiptGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(12);
    final p = Paint()..color = const Color(0xFF2A3354).withOpacity(0.9);
    for (var i = 0; i < 90; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 0.5 + 0.2, p..color = Color.lerp(Colors.white, const Color(0xFF2A3354), rnd.nextDouble() * 0.5)!.withOpacity(0.06));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// CTA Hierarchy — Rewarded Ads vs Primary / Secondary
// ═════════════════════════════════════════════════════════════════════════════

class _ActionHierarchy extends StatelessWidget {
  const _ActionHierarchy({
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

  bool get _canRevive => !isDaily && result != null && !result!.wasRevived && !adsRemoved;
  bool get _canDouble => !isDaily && result != null && !doubleCoinsUsed && !adsRemoved && result!.coinsCollected > 0;

  @override
  Widget build(BuildContext context) {
    final showAds = _canRevive || _canDouble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAds) ...[
          Row(
            children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('BONUS REWARDS',
                  style: AppTypography.overline.copyWith(color: Colors.white.withOpacity(0.72), fontSize: 9, letterSpacing: 1.3)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.16), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.warning.withOpacity(0.28))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_fill_rounded, size: 10, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text('VIDEO', style: AppTypography.overline.copyWith(color: AppColors.warning, fontSize: 8, letterSpacing: 0.9)),
                  ],
                ),
              ),
              const Spacer(),
              Text('optional',
                  style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.28), fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumn = constraints.maxWidth < 320 ||
                  (_canRevive && _canDouble && constraints.maxWidth < 360);
              if (useColumn) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_canRevive)
                      _AdRewardButton(
                        label: 'REVIVE',
                        sublabel: 'Keep flying',
                        icon: Icons.favorite_rounded,
                        color: AppColors.success,
                        badge: 'VIDEO',
                        onTap: onRevive,
                      ),
                    if (_canRevive && _canDouble) const SizedBox(height: 8),
                    if (_canDouble)
                      _AdRewardButton(
                        label: '2× COINS',
                        sublabel: '+${result!.coinsCollected}',
                        icon: Icons.monetization_on_rounded,
                        color: AppColors.coinGold,
                        badge: 'VIDEO',
                        onTap: onDoubleCoins,
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  if (_canRevive)
                    Expanded(
                      child: _AdRewardButton(
                        label: 'REVIVE',
                        sublabel: 'Keep flying',
                        icon: Icons.favorite_rounded,
                        color: AppColors.success,
                        badge: 'VIDEO',
                        onTap: onRevive,
                      ),
                    ),
                  if (_canRevive && _canDouble) const SizedBox(width: 10),
                  if (_canDouble)
                    Expanded(
                      child: _AdRewardButton(
                        label: '2× COINS',
                        sublabel: '+${result!.coinsCollected}',
                        icon: Icons.monetization_on_rounded,
                        color: AppColors.coinGold,
                        badge: 'VIDEO',
                        onTap: onDoubleCoins,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: _DashedLine(color: Colors.white, opacity: 0.12, dashWidth: 4, gapWidth: 6)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR',
                    style: AppTypography.overline.copyWith(color: Colors.white.withOpacity(0.32), fontSize: 9, letterSpacing: 1.0)),
              ),
              const Expanded(child: _DashedLine(color: Colors.white, opacity: 0.12, dashWidth: 4, gapWidth: 6)),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // PRIMARY: RETRY — highest contrast wide pill
        _PrimaryRetryButton(label: isDaily ? 'DAILY BOARD' : 'RETRY', isDaily: isDaily, onTap: onRetry),

        const SizedBox(height: 10),

        // SECONDARY: MENU — outlined / text button
        _SecondaryMenuButton(onTap: onMenu),
      ],
    );
  }
}

class _PrimaryRetryButton extends StatelessWidget {
  const _PrimaryRetryButton({required this.label, required this.isDaily, required this.onTap});
  final String label;
  final bool isDaily;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          boxShadow: [
            BoxShadow(color: HSLColor.fromColor(AppColors.accent).withLightness(0.28).toColor(), offset: const Offset(0, 5), blurRadius: 0),
            BoxShadow(color: Colors.black.withOpacity(0.22), offset: const Offset(0, 8), blurRadius: 12),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // subtle top sheen
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              height: 18,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.22), Colors.transparent],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: AppColors.paperInk.withOpacity(0.14), shape: BoxShape.circle),
                  child: Icon(isDaily ? Icons.calendar_today_rounded : Icons.refresh_rounded, size: 16, color: AppColors.paperInk),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: AppTypography.label.copyWith(color: AppColors.paperInk, fontSize: 17, letterSpacing: 0.8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryMenuButton extends StatelessWidget {
  const _SecondaryMenuButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_rounded, size: 16, color: Colors.white.withOpacity(0.78)),
            const SizedBox(width: 7),
            Text('MENU',
                style: AppTypography.label.copyWith(color: Colors.white.withOpacity(0.88), fontSize: 13, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}

class _AdRewardButton extends StatefulWidget {
  const _AdRewardButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.badge,
    required this.onTap,
  });
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final String badge;
  final VoidCallback onTap;

  @override
  State<_AdRewardButton> createState() => _AdRewardButtonState();
}

class _AdRewardButtonState extends State<_AdRewardButton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, child) {
          return Container(
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.paperBright,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.color, width: 1.7),
              boxShadow: [
                BoxShadow(color: _edge(widget.color), offset: const Offset(0, 3.5), blurRadius: 0),
                BoxShadow(color: widget.color.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // shimmer sweep
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset((_shimmer.value * 220) - 90, 0),
                      child: Transform.rotate(
                        angle: 0.22,
                        child: Container(
                          width: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.white.withOpacity(0.42), Colors.transparent],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // icon with video-play badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: widget.color.withOpacity(0.16), borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.color.withOpacity(0.28))),
                              child: Icon(widget.icon, color: widget.color, size: 18),
                            ),
                            Positioned(
                              right: -5,
                              bottom: -5,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: widget.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.4),
                                  boxShadow: [BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 4)],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, size: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(widget.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.label.copyWith(color: widget.color, fontSize: 13, letterSpacing: 0.6)),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(4)),
                                    child: Text(widget.badge,
                                        style: AppTypography.overline.copyWith(color: Colors.white, fontSize: 7, letterSpacing: 0.7)),
                                  ),
                                ],
                              ),
                              Text(widget.sublabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _edge(Color c) => HSLColor.fromColor(c).withLightness(0.38).toColor();
}
