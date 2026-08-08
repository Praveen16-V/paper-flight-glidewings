import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/widgets/paper_icons.dart';
import '../../providers/game_session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/daily_seed_service.dart';
import '../paper_flight_game.dart';

/// Flutter widget HUD drawn on top of the Flame canvas via GameWidget overlays.
///
/// Uses Riverpod to reactively update — the game loop pushes score/distance
/// to gameSessionProvider every ~0.1s and the HUD rebuilds only those fields.
class HudOverlay extends ConsumerWidget {
  const HudOverlay({super.key, required this.game});

  final PaperFlightGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    final settings = ref.watch(settingsProvider);
    final trial = session.mode == GameMode.trial ? game.trial : null;

    return SafeArea(
      child: Stack(
        children: [
          // ── Top bar (mode-aware, Task 8) ───────────────────────────────
          if (session.mode == GameMode.trial && trial != null) ...[
            // Precision Trial: objective pill + coin counter, big clock.
            Positioned(
              top: 12,
              left: 16,
              right: 72,
              child: _TrialObjectiveBar(
                objective: trial.objective,
                coins: session.coinsThisRun,
                totalCoins: trial.totalCoins,
              ),
            ),
            if (trial.parSeconds != null)
              Positioned(
                top: 58,
                left: 0,
                right: 0,
                child: Center(
                  child: _TrialTimer(
                    timeLeft: session.trialTimeLeft,
                    par: trial.parSeconds,
                  ),
                ),
              ),
          ] else ...[
            Positioned(
              top: 12,
              left: 16,
              right: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (session.mode == GameMode.zen)
                    const _ModeTag(label: 'ZEN', color: Color(0xFF66BB6A))
                  else if (session.mode == GameMode.daily)
                    _ModeTag(
                      label: DailySeedService.label(game.dailySeed),
                      color: AppColors.accentAlt,
                    )
                  else
                    _ScoreDisplay(
                      score: session.score,
                      isNew: session.lastRunResult?.isNewHighScore ?? false,
                    ),
                  _CoinDisplay(coins: session.coinsThisRun),
                ],
              ),
            ),
          ],

          // ── Distance meter / Zen clock ────────────────────────────────
          if (session.mode == GameMode.zen)
            Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Center(
                child: _ZenStatusDisplay(
                  meters: session.distanceMeters,
                  seconds: session.runTimeSeconds,
                ),
              ),
            )
          else if (session.mode != GameMode.trial)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: _DistanceDisplay(meters: session.distanceMeters),
              ),
            ),

          // ── Combo strip + decay gauge (classic + daily only) ──────────
          if (session.comboCount >= 3 &&
              (session.mode == GameMode.classic ||
                  session.mode == GameMode.daily))
            Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: Center(
                child: _ComboDisplay(
                  count: session.comboCount,
                  multiplier: session.comboMultiplier,
                  gauge: session.comboGauge,
                ),
              ),
            ),

          // ── Active power-up icons (bottom-left) ────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 100,
            left: 16,
            child: _PowerUpBar(
              activePowerUps: session.activePowerUps,
              remaining: session.powerUpRemaining,
            ),
          ),

          // ── Pause button — 44×44 with border for visibility ────────────
          Positioned(
            top: 12,
            right: 16,
            child: _PauseButton(game: game),
          ),

          // ── BOOST button — respects gesture-nav bottom inset ───────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 18,
            right: 16,
            child: _BoostButton(game: game),
          ),

          // ── Joystick hint — two-line, narrower, readable ───────────────
          if (settings.controlScheme == ControlScheme.joystick &&
              session.phase == GamePhase.playing)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 110,
              left: 32,
              right: 32,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xBB000000),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'MOVE THUMB TO STEER  •  HOLD TO CLIMB\nFLICK UP OR TAP BOOST',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

          // ── Biome label — moved lower, less intrusive ─────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 28,
            left: 0,
            right: 80, // avoid BOOST button area
            child: Center(
              child: _BiomeLabel(biome: session.currentBiome),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({required this.score, required this.isNew});
  final int score;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.hudBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNew)
            const Text('★ ', style: TextStyle(color: AppColors.warning, fontSize: 14)),
          Text(
            _formatScore(score),
            style: const TextStyle(
              fontFamily: AppTypography.mono,
              color: AppColors.textLight,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatScore(int s) {
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}M';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return s.toString();
  }
}

class _CoinDisplay extends StatelessWidget {
  const _CoinDisplay({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.hudBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaperIcon(PaperIconData.coin, size: 16, color: AppColors.coinGold),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(
              fontFamily: AppTypography.mono,
              color: AppColors.coinGold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceDisplay extends StatelessWidget {
  const _DistanceDisplay({required this.meters});
  final double meters;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${meters.toStringAsFixed(0)} m',
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}

/// Small labelled pill shown in place of the score for Zen / Daily modes.
class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.hudBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Zen Flight: distance + elapsed time, calm and quiet.
class _ZenStatusDisplay extends StatelessWidget {
  const _ZenStatusDisplay({required this.meters, required this.seconds});
  final double meters;
  final double seconds;

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final secs = (seconds % 60).toStringAsFixed(0).padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${meters.toStringAsFixed(0)} m',
          style: const TextStyle(
            fontFamily: AppTypography.mono,
            fontFeatures: [FontFeature.tabularFigures()],
            color: AppColors.textLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$minutes:$secs',
          style: const TextStyle(
            fontFamily: AppTypography.mono,
            fontFeatures: [FontFeature.tabularFigures()],
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Precision Trial: objective + coins collected/total.
class _TrialObjectiveBar extends StatelessWidget {
  const _TrialObjectiveBar({
    required this.objective,
    required this.coins,
    required this.totalCoins,
  });
  final String objective;
  final int coins;
  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.hudBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.textLight, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              objective,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (totalCoins > 0) ...[
            const SizedBox(width: 10),
            PaperIcon(PaperIconData.coin, size: 12, color: AppColors.coinGold),
            const SizedBox(width: 4),
            Text(
              '$coins/$totalCoins',
              style: const TextStyle(
                fontFamily: AppTypography.mono,
                color: AppColors.coinGold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Precision Trial countdown — turns amber under 5s, red under 3s.
class _TrialTimer extends StatelessWidget {
  const _TrialTimer({required this.timeLeft, required this.par});
  final double? timeLeft;
  final double? par;

  @override
  Widget build(BuildContext context) {
    final remaining = timeLeft ?? par ?? 0;
    final urgent = remaining < 5;
    final critical = remaining < 3;
    return Text(
      '${remaining.toStringAsFixed(1)}s',
      style: TextStyle(
        fontFamily: AppTypography.mono,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: critical
            ? const Color(0xFFFF1744)
            : urgent
                ? const Color(0xFFFFB300)
                : AppColors.textLight,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        shadows: const [
          Shadow(color: Colors.black45, blurRadius: 6),
        ],
      ),
    );
  }
}

class _ComboDisplay extends StatelessWidget {
  const _ComboDisplay({
    required this.count,
    required this.multiplier,
    required this.gauge,
  });
  final int count;
  final double multiplier;

  /// Combo decay gauge, 0.0–1.0 — drains while no coins are collected.
  final double gauge;

  @override
  Widget build(BuildContext context) {
    final gaugeFraction = gauge.clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: count > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFF5A623)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '×${multiplier.toStringAsFixed(1)}  $count COMBO',
              style: const TextStyle(
                fontFamily: AppTypography.display,
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        // Decay gauge — visibly burns down from full; refills one notch
        // per coin. Shifts hot-orange → red as it empties.
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            width: 110,
            height: 4,
            color: const Color(0x33FFFFFF),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: gaugeFraction,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gaugeFraction > 0.3
                        ? const [Color(0xFFFF6B35), Color(0xFFF5A623)]
                        : const [Color(0xFFFF1744), Color(0xFFFF6B35)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PowerUpBar extends StatelessWidget {
  const _PowerUpBar({required this.activePowerUps, required this.remaining});
  final Set<PowerUpType> activePowerUps;
  final Map<PowerUpType, double> remaining;

  @override
  Widget build(BuildContext context) {
    if (activePowerUps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: activePowerUps.map((type) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _PowerUpIcon(type: type, remaining: remaining[type]),
        );
      }).toList(),
    );
  }
}

class _PowerUpIcon extends StatelessWidget {
  const _PowerUpIcon({required this.type, this.remaining});
  final PowerUpType type;
  final double? remaining;

  @override
  Widget build(BuildContext context) {
    final warning = remaining != null && remaining! <= 1.5;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: warning ? 1 : 0), duration: const Duration(milliseconds: 280),
      builder: (context, pulse, child) => CustomPaint(
        painter: _PowerTimerPainter(progress: remaining == null ? 1 : (remaining! / _duration(type)).clamp(0.0, 1.0), warning: warning, pulse: pulse),
        child: child,
      ),
      child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _colorForType(type),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: _colorForType(type).withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _iconForType(type),
          color: Colors.white,
          size: 18,
        ),
      ),
    ));
  }

  double _duration(PowerUpType type) => switch (type) { PowerUpType.magnet => GameConfig.magnetDuration, PowerUpType.ghost => GameConfig.ghostDuration, PowerUpType.slowMo => GameConfig.slowMoDuration, PowerUpType.coinRush => GameConfig.coinRushDuration, _ => 1 };

  Color _colorForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return const Color(0xFF1565C0);
      case PowerUpType.magnet:
        return const Color(0xFF6A1B9A);
      case PowerUpType.ghost:
        return const Color(0xFF00838F);
      case PowerUpType.slowMo:
        return const Color(0xFF00695C);
      case PowerUpType.coinRush:
        return const Color(0xFFC77800);
    }
  }

  IconData _iconForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return Icons.shield_rounded;
      case PowerUpType.magnet:
        return Icons.my_location_rounded;
      case PowerUpType.ghost:
        return Icons.visibility_off_rounded;
      case PowerUpType.slowMo:
        return Icons.timer_rounded;
      case PowerUpType.coinRush:
        return Icons.monetization_on_rounded;
    }
  }
}

class _PowerTimerPainter extends CustomPainter { const _PowerTimerPainter({required this.progress, required this.warning, required this.pulse}); final double progress; final bool warning; final double pulse; @override void paint(Canvas c, Size s) { final p=Paint()..color=(warning ? Colors.redAccent : Colors.white).withOpacity(warning ? .65 + pulse*.35 : .85)..style=PaintingStyle.stroke..strokeWidth=2.5..strokeCap=StrokeCap.round; c.drawArc(Rect.fromLTWH(1,1,s.width-2,s.height-2),-1.57,6.283*progress,false,p); } @override bool shouldRepaint(covariant _PowerTimerPainter o)=>o.progress!=progress||o.warning!=warning||o.pulse!=pulse; }

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.game});
  final PaperFlightGame game;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (game.phase == GamePhase.playing) {
          game.pauseRun();
        } else if (game.phase == GamePhase.paused) {
          game.resumeRun();
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.hudBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          game.phase == GamePhase.paused ? Icons.play_arrow : Icons.pause,
          color: AppColors.textLight,
          size: 22,
        ),
      ),
    );
  }
}

/// Dedicated emergency BOOST button with charge-ring indicator.
///
/// Tapping fires one snap charge if available. Shows 2 charge dots
/// and a circular progress sweep for the recharging charge.
class _BoostButton extends StatefulWidget {
  const _BoostButton({required this.game});
  final PaperFlightGame game;

  @override
  State<_BoostButton> createState() => _BoostButtonState();
}

class _BoostButtonState extends State<_BoostButton>
    with SingleTickerProviderStateMixin {
  // Ticker drives the BOOST recharge-ring animation at 60fps.
  // Explicit `Ticker` type requires `package:flutter/scheduler.dart` (already imported).
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charges = widget.game.inputManager.snapCharges;
    final progress = widget.game.inputManager.snapRechargeFraction;
    final hasCharges = charges > 0;
    final isPlaying = widget.game.phase == GamePhase.playing;

    return Opacity(
      opacity: isPlaying ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: isPlaying
            ? () {
                final fired = widget.game.triggerSnapBoost();
                if (fired && mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
              }
            : null,
        child: SizedBox(
          width: 72,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Charge ring behind button
              SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _BoostRingPainter(
                    charges: charges,
                    maxCharges: GameConfig.snapMaxCharges,
                    progress: progress,
                  ),
                ),
              ),
              // Main circular button
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: hasCharges ? const Color(0xFFF5A623) : const Color(0xFF3A4D7A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasCharges ? Colors.white.withOpacity(0.9) : Colors.white24,
                    width: 2,
                  ),
                  boxShadow: [
                    if (hasCharges)
                      BoxShadow(
                        color: const Color(0xFFF5A623).withOpacity(0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: hasCharges ? Colors.white : const Color(0xFF8A9BB8),
                      size: 22,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      hasCharges ? 'BOOST' : 'WAIT',
                      style: TextStyle(
                        color: hasCharges ? Colors.white : const Color(0xFF8A9BB8),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Charge dots
              Positioned(
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(GameConfig.snapMaxCharges, (i) {
                    final filled = i < charges;
                    // Next charge is recharging partially
                    final isRecharging = i == charges && !filled && progress > 0.02;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: filled
                            ? const Color(0xFFF5A623)
                            : isRecharging
                                ? const Color(0xFFF5A623).withOpacity(0.35 + 0.4 * progress)
                                : Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoostRingPainter extends CustomPainter {
  _BoostRingPainter({
    required this.charges,
    required this.maxCharges,
    required this.progress,
  });

  final int charges;
  final int maxCharges;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const gap = 0.22;
    final totalArc = (2 * 3.1415926535 - gap * maxCharges) / maxCharges;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    for (int i = 0; i < maxCharges; i++) {
      final start = -3.1415926535 / 2 + i * (totalArc + gap);
      double sweep = totalArc;
      Paint? segPaint;
      bool draw = true;

      if (i < charges) {
        segPaint = Paint()
          ..color = const Color(0xFFF5A623)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
      } else if (i == charges && charges < maxCharges) {
        if (progress <= 0.01) {
          draw = false;
        } else {
          sweep = totalArc * progress.clamp(0.0, 1.0);
          segPaint = Paint()
            ..color = const Color(0xFFF5A623).withOpacity(0.5 + 0.35 * progress)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round;
        }
      } else {
        segPaint = Paint()
          ..color = const Color(0x33FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
      }

      if (!draw || segPaint == null) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        segPaint!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoostRingPainter oldDelegate) =>
      oldDelegate.charges != charges || oldDelegate.progress != progress;
}

class _BiomeLabel extends StatelessWidget {
  const _BiomeLabel({required this.biome});
  final Biome biome;

  @override
  Widget build(BuildContext context) {
    return Text(
      biome.displayName.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}
