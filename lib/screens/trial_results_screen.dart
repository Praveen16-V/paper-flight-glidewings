import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../core/widgets/stat_counter.dart';
import '../models/trial_definition.dart';
import '../providers/game_session_provider.dart';
import 'game_screen.dart';

/// Route args for the trial results screen.
class TrialResultArgs {
  const TrialResultArgs({this.outcome});
  final TrialOutcome? outcome;
}

/// Results screen shown after a Precision Trial finishes — now with
/// papercraft star celebration, confetti bursts, shake and Your-vs-Par bar.
class TrialResultsScreen extends StatefulWidget {
  const TrialResultsScreen({super.key, required this.args});
  final TrialResultArgs args;

  @override
  State<TrialResultsScreen> createState() => _TrialResultsScreenState();
}

class _TrialResultsScreenState extends State<TrialResultsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _shake;
  late final Animation<double> _shakeOffset;
  final List<_ConfettiParticle> _confetti = [];
  late final AnimationController _confettiTicker;
  int _visibleStars = 0;

  // per-star scale animations
  late final List<AnimationController> _starCtrls;
  late final List<Animation<double>> _starScales;
  late final List<Animation<double>> _starRot;

  TrialOutcome? get _outcome => widget.args.outcome;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -7.0), weight: 12),
      TweenSequenceItem(tween: Tween<double>(begin: -7.0, end: 7.0), weight: 18),
      TweenSequenceItem(tween: Tween<double>(begin: 7.0, end: -4.0), weight: 14),
      TweenSequenceItem(tween: Tween<double>(begin: -4.0, end: 3.0), weight: 12),
      TweenSequenceItem(tween: Tween<double>(begin: 3.0, end: 0.0), weight: 14),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));

    _confettiTicker = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _confettiTicker.addListener(_tickConfetti);

    _starCtrls = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 520)));
    _starScales = _starCtrls
        .map((c) => TweenSequence<double>([
              TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.28).chain(CurveTween(curve: Curves.easeOutBack)), weight: 55),
              TweenSequenceItem(tween: Tween<double>(begin: 1.28, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 45),
            ]).animate(c))
        .toList();
    _starRot = _starCtrls
        .map((c) => Tween<double>(begin: -0.18, end: 0).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    _scheduleStars();
  }

  void _scheduleStars() async {
    final outcome = _outcome;
    if (outcome == null) return;
    await Future.delayed(const Duration(milliseconds: 380));
    for (var s = 1; s <= 3; s++) {
      if (!mounted) return;
      _starCtrls[s - 1].forward(from: 0);
      setState(() => _visibleStars = s);
      if (s <= outcome.stars) {
        _triggerShake();
        _burstConfetti(atStar: s);
      }
      await Future.delayed(const Duration(milliseconds: 420));
    }
    // Fix 4: stop confetti ticker ~2s after last burst (all confetti settled)
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) _confettiTicker.stop();
  }

  void _triggerShake() {
    if (_outcome != null && _outcome!.stars > 0) {
      _shake.forward(from: 0);
    }
  }

  void _burstConfetti({required int atStar}) {
    final rnd = math.Random(atStar * 999 + DateTime.now().microsecond);
    // origin roughly around star row center; will be positioned via overlay center
    // Instead we spawn at normalized center (0,0) and confetti canvas translates to center
    const count = 16;
    final colors = [
      AppColors.warning,
      AppColors.accent,
      AppColors.coinGold,
      AppColors.success,
      AppColors.accentAlt,
      const Color(0xFFFF6B6B),
      const Color(0xFFCE93D8),
    ];
    for (var i = 0; i < count; i++) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final speed = 70 + rnd.nextDouble() * 140;
      final vx = math.cos(angle) * speed * (0.7 + rnd.nextDouble() * 0.6);
      final vy = math.sin(angle) * speed * 0.7 - 90 - rnd.nextDouble() * 60; // upward bias
      _confetti.add(_ConfettiParticle(
        x: 0,
        y: 0,
        vx: vx,
        vy: vy,
        rotation: rnd.nextDouble() * math.pi * 2,
        rotationSpeed: (rnd.nextDouble() - 0.5) * 7,
        color: colors[rnd.nextInt(colors.length)],
        w: 7 + rnd.nextDouble() * 6,
        h: 4 + rnd.nextDouble() * 5,
        life: 0,
      ));
    }
  }

  void _tickConfetti() {
    // Fix 4: guard — skip processing when nothing to animate
    if (_confetti.isEmpty) return;

    const dt = 0.016;
    const gravity = 420.0;
    const drag = 0.98;
    for (final p in _confetti) {
      p.life += dt;
      p.vy += gravity * dt;
      p.vx *= drag;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rotation += p.rotationSpeed * dt;
    }
    _confetti.removeWhere((p) => p.life > 2.2 || p.y > 420);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry.dispose();
    _shake.dispose();
    _confettiTicker.dispose();
    for (final c in _starCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    final trial = outcome == null ? null : TrialPool.byId(outcome.trialId);
    final completed = outcome?.completed == true;

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
          child: AnimatedBuilder(
            animation: _shakeOffset,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeOffset.value, 0),
                child: child,
              );
            },
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _entry, curve: Curves.easeIn),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    Text(
                      outcome == null
                          ? 'TRIAL'
                          : completed
                              ? 'COURSE COMPLETE'
                              : outcome.timedOut
                                  ? 'TIME UP'
                                  : 'CRASHED',
                      style: AppTypography.displayMedium.copyWith(
                        color: completed ? AppColors.success : AppColors.danger,
                        fontSize: 26,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(trial?.title ?? '', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                    if (trial != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(trial.objective,
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted.withOpacity(0.75), fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 22),

                    if (outcome != null) ...[
                      // stars + confetti overlay
                      SizedBox(
                        height: 86,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // confetti behind stars but above background
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _ConfettiPainter(particles: _confetti),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int s = 1; s <= 3; s++) _buildStar(s, outcome.stars),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (outcome.isNewBestStars) ...[
                        const SizedBox(height: 8),
                        ScaleTransition(
                          scale: CurvedAnimation(
                              parent: _starCtrls[(outcome.stars.clamp(1, 3) - 1)],
                              curve: Curves.elasticOut),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.warning.withOpacity(0.55)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.warning),
                                const SizedBox(width: 6),
                                Text('NEW BEST!',
                                    style: AppTypography.label.copyWith(color: AppColors.warning, letterSpacing: 1.6, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (!completed) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                          ),
                          child: Text(
                            outcome.timedOut ? 'The clock ran out — fly faster!' : 'One touch ends the run — try again!',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(fontSize: 12, color: AppColors.textLight.withOpacity(0.85)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      PaperCard(
                        color: completed ? AppColors.paperGreen : AppColors.paperRose,
                        elevation: 1.6,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        dogEar: completed ? const DogEar(label: 'DONE', color: AppColors.success, size: 56) : null,
                        child: Column(
                          children: [
                            // Time row
                            _StatRow(label: 'Time', value: outcome.timeUsedSeconds, suffix: ' s'),
                            Divider(color: AppColors.paperInkSoft.withOpacity(0.25), height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    PaperIcon(PaperIconData.coin, size: 14, color: AppColors.coinGold),
                                    const SizedBox(width: 6),
                                    Text('Coins',
                                        style: AppTypography.bodyMedium.copyWith(color: AppColors.paperInkSoft)),
                                  ],
                                ),
                                StatCounter(
                                  outcome.coinsCollected,
                                  suffix: '/${outcome.totalCoins}',
                                  style: AppTypography.statSmall.copyWith(color: AppColors.coinGoldDeep),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Fix 1: Par comparison bar moved OUTSIDE stats card — now prominent
                      if (trial?.parSeconds != null) ...[
                        const SizedBox(height: 12),
                        PaperCard(
                          color: AppColors.paperBright,
                          elevation: 1.2,
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.compare_arrows_rounded,
                                      size: 14, color: AppColors.accentAlt),
                                  const SizedBox(width: 6),
                                  Text('VS PAR',
                                      style: AppTypography.overline.copyWith(
                                          color: AppColors.paperInkSoft,
                                          letterSpacing: 1.4)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _ParComparisonBar(
                                yourTime: outcome.timeUsedSeconds,
                                parTime: trial!.parSeconds!,
                                completed: completed,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const Spacer(),
                    if (trial != null) ...[
                      PaperButton(
                        label: 'FLY AGAIN',
                        expand: true,
                        onPressed: () => _retry(trial),
                      ),
                      const SizedBox(height: 12),
                      // Fix 2: removed duplicate MENU button (both navigated to AppRoutes.trials)
                      // Single TRIAL MAP button replaces both MENU + TRIALS
                      PaperButton(
                        label: 'TRIAL MAP',
                        expand: true,
                        color: AppColors.paperBlue,
                        textColor: AppColors.gemBlueDeep,
                        icon: const Icon(Icons.map_rounded, size: 18, color: AppColors.gemBlueDeep),
                        onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.trials),
                      ),
                      if (outcome?.completed == true && outcome!.stars >= 1) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => _nextTrial(trial),
                          child: Text('NEXT TRIAL →',
                              style: AppTypography.label.copyWith(color: AppColors.accentAlt, letterSpacing: 1)),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStar(int index, int earned) {
    final isEarned = index <= earned;
    final visible = index <= _visibleStars;
    final scale = _starScales[index - 1];
    final rot = _starRot[index - 1];

    if (!visible) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.star_border_rounded, size: 54, color: AppColors.textMuted.withOpacity(0.18)),
      );
    }

    return ScaleTransition(
      scale: scale,
      child: RotationTransition(
        turns: Tween<double>(begin: -0.05, end: 0).animate(_starCtrls[index - 1]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // paper shadow behind earned star
              if (isEarned)
                Transform.translate(
                  offset: const Offset(2, 3),
                  child: Icon(Icons.star_rounded, size: 54, color: Colors.black.withOpacity(0.18)),
                ),
              Icon(
                isEarned ? Icons.star_rounded : Icons.star_border_rounded,
                size: 54,
                color: isEarned ? AppColors.warning : AppColors.textMuted.withOpacity(0.32),
              ),
              if (isEarned)
                // highlight glint
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.55), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _retry(TrialDefinition trial) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.game, arguments: GameScreenArgs(mode: GameMode.trial, trialId: trial.id));
  }

  void _nextTrial(TrialDefinition trial) {
    final next = TrialPool.byId(trial.id + 1);
    if (next == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.trials);
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.game, arguments: GameScreenArgs(mode: GameMode.trial, trialId: next.id));
  }
}

class _ParComparisonBar extends StatelessWidget {
  const _ParComparisonBar({required this.yourTime, required this.parTime, required this.completed});
  final double yourTime;
  final double parTime;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final delta = parTime - yourTime; // positive = faster
    final isFaster = delta > 0.05;
    final isSlower = delta < -0.05;
    final isPar = !isFaster && !isSlower;
    final deltaAbs = delta.abs();
    final deltaText = isPar
        ? 'on par'
        : isFaster
            ? '-${deltaAbs.toStringAsFixed(1)}s faster than par'
            : '+${deltaAbs.toStringAsFixed(1)}s slower than par';
    final deltaColor = isFaster ? AppColors.success : (isSlower ? AppColors.danger : AppColors.paperInkSoft);

    // bar geometry: par position at 62% of bar
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your Time', style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: deltaColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: deltaColor.withOpacity(0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isFaster ? Icons.bolt_rounded : (isSlower ? Icons.timer_off_rounded : Icons.check_circle_rounded),
                      size: 11, color: deltaColor),
                  const SizedBox(width: 4),
                  Text(deltaText,
                      style: AppTypography.caption.copyWith(color: deltaColor, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          const parRatio = 0.62;
          final parX = w * parRatio;
          final yourX = (yourTime / parTime * parX).clamp(8.0, w - 8.0);
          final isYourFaster = yourX < parX - 2;
          return Column(
            children: [
              SizedBox(
                height: 30,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // track
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 12,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.paperWarm,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black.withOpacity(0.06)),
                        ),
                      ),
                    ),
                    // delta fill between par and your
                    Positioned(
                      left: math.min(parX, yourX),
                      top: 12,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (parX - yourX).abs()),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, animW, _) {
                          return Container(
                            width: animW,
                            height: 8,
                            decoration: BoxDecoration(
                              color: deltaColor.withOpacity(0.72),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        },
                      ),
                    ),
                    // par marker
                    Positioned(
                      left: parX - 1,
                      top: 4,
                      child: Column(
                        children: [
                          Container(
                            width: 2,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.paperInk,
                              borderRadius: BorderRadius.circular(1),
                              border: Border.all(color: Colors.white.withOpacity(0.85), width: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: parX - 18,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.paperInk, borderRadius: BorderRadius.circular(4)),
                        child: Text('PAR',
                            style: AppTypography.overline.copyWith(color: Colors.white, fontSize: 7, letterSpacing: 0.8)),
                      ),
                    ),
                    // your dot
                    Positioned(
                      left: yourX - 9,
                      top: 7,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 620),
                        curve: Curves.easeOutBack,
                        builder: (context, s, _) {
                          return Transform.scale(
                            scale: s,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: isFaster ? AppColors.success : (isSlower ? AppColors.danger : AppColors.accent),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: (isFaster ? AppColors.success : AppColors.danger).withOpacity(0.32), blurRadius: 6)],
                              ),
                              child: Icon(Icons.flight_rounded, size: 9, color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: yourTime),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text('${v.toStringAsFixed(1)}s',
                        style: TextStyle(fontFamily: AppTypography.mono, fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.paperInk)),
                  ),
                  Text('${parTime.toStringAsFixed(1)}s  PAR',
                      style: TextStyle(fontFamily: AppTypography.mono, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.paperInkSoft)),
                ],
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.w,
    required this.h,
    required this.life,
  });
  double x, y, vx, vy, rotation, rotationSpeed;
  Color color;
  double w, h;
  double life;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles});
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 4);
    for (final p in particles) {
      final alpha = (1 - (p.life / 1.8)).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      canvas.save();
      canvas.translate(center.dx + p.x, center.dy + p.y);
      canvas.rotate(p.rotation);
      final rect = Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h);
      final paint = Paint()..color = p.color.withOpacity(alpha * 0.95);
      // paper confetti with slight fold line
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(1.2)), paint);
      // fold highlight
      canvas.drawLine(
          Offset(-p.w / 2, 0), Offset(p.w / 2, 0), Paint()..color = Colors.white.withOpacity(alpha * 0.28)..strokeWidth = 0.8);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.suffix = '', this.valueColor});
  final String label;
  final double value;
  final String suffix;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.paperInkSoft)),
        StatCounter(
          value,
          suffix: suffix,
          style: AppTypography.stat.copyWith(color: valueColor ?? AppColors.paperInk, fontSize: 16),
        ),
      ],
    );
  }
}
