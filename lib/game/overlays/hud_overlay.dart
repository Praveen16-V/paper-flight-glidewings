import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/widgets/mode_card.dart';
import '../../core/widgets/paper_icons.dart';
import '../../core/widgets/powerup_emblem.dart';
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
                    const _ModeTag(label: 'ZEN', color: AppColors.modeZen)
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

          // ── Pickup announcement ────────────────────────────────────────
          // Centred above the plane, clear of the score and combo strips.
          if (session.pickupAnnouncement != null)
            Positioned(
              top: 132,
              left: 0,
              right: 0,
              child: Center(
                child: _PickupAnnouncementBanner(
                  announcement: session.pickupAnnouncement!,
                  paused: session.phase != GamePhase.playing,
                  onDismiss: (id) => ref
                      .read(gameSessionProvider.notifier)
                      .clearPickupAnnouncement(id),
                ),
              ),
            ),

          // ── Active power-up icons (bottom-left) ────────────────────────
          Positioned(
            bottom: 100,
            left: 16,
            child: _PowerUpBar(
              activePowerUps: session.activePowerUps,
              activeCombos: session.activePowerUpCombos,
              activeCorrupted: session.activeCorruptedPowerUps,
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
            bottom: 18,
            right: 16,
            child: _BoostButton(game: game),
          ),

          // ── Joystick hint — two-line, narrower, readable ───────────────
          if (settings.controlScheme == ControlScheme.joystick &&
              session.phase == GamePhase.playing)
            Positioned(
              bottom: 110,
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
                      color: Color(0xFFF3F6FB),
                      fontSize: 12,
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
            bottom: 28,
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

/// Compact cream paper strip for HUD readouts (bridges menu aesthetic).
class _HudPaperStrip extends StatelessWidget {
  const _HudPaperStrip({
    required this.child,
    this.calm = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final bool calm;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: calm ? AppColors.hudPaperZen : AppColors.hudPaper,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.paperInk.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.paperInk.withOpacity(0.12),
            offset: const Offset(0, 2),
            blurRadius: 4,
            spreadRadius: -1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({required this.score, required this.isNew});
  final int score;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return _HudPaperStrip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNew)
            const Text('★ ', style: TextStyle(color: AppColors.warning, fontSize: 14)),
          Text(
            _formatScore(score),
            style: const TextStyle(
              fontFamily: AppTypography.mono,
              color: AppColors.paperInk,
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
    return _HudPaperStrip(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaperIcon(PaperIconData.coin, size: 16, color: AppColors.coinGoldDeep),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(
              fontFamily: AppTypography.mono,
              color: AppColors.coinGoldDeep,
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
    final label = '${meters.toStringAsFixed(0)} m';
    return Semantics(
      label: 'Distance $label',
      child: ExcludeSemantics(
        child: _HudPaperStrip(
          calm: true,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          radius: AppRadius.button,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.paperInkSoft,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
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
        color: AppColors.hudPaper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.45), width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: darkenModeColor(color, 0.15),
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
    return _HudPaperStrip(
      calm: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${meters.toStringAsFixed(0)} m',
            style: const TextStyle(
              fontFamily: AppTypography.mono,
              fontFeatures: [FontFeature.tabularFigures()],
              color: AppColors.paperInk,
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
              color: AppColors.paperInkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
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
                colors: [AppColors.danger, AppColors.accent],
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
                        ? [AppColors.danger, AppColors.accent]
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

/// Shows what is running right now, and nothing else.
///
/// Power-ups activate the moment they are collected, so there is no inventory
/// to display and no button to press — every row here is a live effect with a
/// draining countdown, and it disappears the instant that effect ends.
class _PowerUpBar extends StatelessWidget {
  const _PowerUpBar({
    required this.activePowerUps,
    required this.activeCombos,
    required this.activeCorrupted,
    required this.remaining,
  });
  final Set<PowerUpType> activePowerUps;
  final Set<PowerUpCombo> activeCombos;
  final Set<CorruptedPowerUpType> activeCorrupted;
  final Map<PowerUpType, double> remaining;

  @override
  Widget build(BuildContext context) {
    if (activePowerUps.isEmpty && activeCorrupted.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final combo in activeCombos)
          Padding(
            key: ValueKey('combo.${combo.name}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: _PowerUpComboPill(combo: combo),
          ),
        for (final corrupted in activeCorrupted)
          Padding(
            key: ValueKey('corrupt.${corrupted.name}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: _CorruptedPowerUpPill(type: corrupted),
          ),
        // Keyed by type so Flutter animates the row that actually changed
        // rather than reusing a neighbour's slot when one effect ends.
        ...activePowerUps.map((type) {
          return Padding(
            key: ValueKey('power.${type.name}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: _PowerUpIcon(type: type, remaining: remaining[type]),
          );
        }),
      ],
    );
  }
}

/// The "you just picked this up" banner.
///
/// Power-ups now activate on contact, so the player never chooses when an
/// effect starts — that makes a clear, immediate announcement essential:
/// without it, a Shrink or a Wind Caller changes how the plane behaves with no
/// explanation. The banner names the pickup, shows its emblem, and says in a
/// few words what it does, then gets out of the way.
class _PickupAnnouncementBanner extends StatefulWidget {
  const _PickupAnnouncementBanner({
    super.key,
    required this.announcement,
    required this.paused,
    required this.onDismiss,
  });

  final PickupAnnouncement announcement;

  /// While the run is paused the banner holds its place instead of timing
  /// out behind the pause menu.
  final bool paused;

  final void Function(int id) onDismiss;

  @override
  State<_PickupAnnouncementBanner> createState() =>
      _PickupAnnouncementBannerState();
}

class _PickupAnnouncementBannerState extends State<_PickupAnnouncementBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds:
          (GameConfig.pickupAnnouncementSeconds * 1000).round(),
    ),
  );

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(covariant _PickupAnnouncementBanner old) {
    super.didUpdateWidget(old);
    // A new pickup (even the same type again) restarts the entry animation.
    if (old.announcement.id != widget.announcement.id) {
      _play();
    } else if (old.paused != widget.paused) {
      if (widget.paused) {
        _controller.stop();
      } else {
        _resume();
      }
    }
  }

  void _play() => _resume(from: 0);

  void _resume({double? from}) {
    if (widget.paused) return;
    _controller.forward(from: from).whenComplete(() {
      // Only dismiss on a genuine completion, not on an interruption from a
      // pause or a replacing pickup.
      if (mounted && _controller.value >= 1.0) {
        widget.onDismiss(widget.announcement.id);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final tint = a.isCorrupted ? a.corrupted!.color : a.type.visualColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Pop in fast, hold, then fade and drift up on the way out.
        final entryT = (t / 0.18).clamp(0.0, 1.0);
        // easeOutBack overshoots past 1, which is what gives the pop; keep it
        // for motion but drive opacity from the un-overshot progress.
        final entry = Curves.easeOutBack.transform(entryT);
        final exit = t < 0.72 ? 0.0 : ((t - 0.72) / 0.28).clamp(0.0, 1.0);
        final opacity = (entryT - exit).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - entry) * 16 - exit * 20),
            child: Transform.scale(scale: 0.86 + 0.14 * entry, child: child),
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1520).withOpacity(.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withOpacity(.85), width: 1.6),
          boxShadow: [
            BoxShadow(color: tint.withOpacity(.45), blurRadius: 16),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PowerUpEmblem(type: a.type, size: 34),
              const SizedBox(width: 11),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: AppTypography.overline.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    a.subtitle,
                    style: AppTypography.overline.copyWith(
                      color: tint,
                      fontSize: 10,
                      letterSpacing: .3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerUpComboPill extends StatelessWidget {
  const _PowerUpComboPill({required this.combo});
  final PowerUpCombo combo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: combo.color.withOpacity(.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.72)),
        boxShadow: [
          BoxShadow(
            color: combo.color.withOpacity(.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        combo.displayName.toUpperCase(),
        style: AppTypography.overline.copyWith(
          color: Colors.white,
          fontSize: 8,
          letterSpacing: .7,
        ),
      ),
    );
  }
}

class _CorruptedPowerUpPill extends StatelessWidget {
  const _CorruptedPowerUpPill({required this.type});
  final CorruptedPowerUpType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withOpacity(.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.72)),
      ),
      child: Text(
        type.displayName.toUpperCase(),
        style: AppTypography.overline.copyWith(
          color: Colors.white,
          fontSize: 8,
          letterSpacing: .55,
        ),
      ),
    );
  }
}

class _PowerUpIcon extends StatelessWidget {
  const _PowerUpIcon({required this.type, this.remaining});
  final PowerUpType type;
  final double? remaining;

  @override
  Widget build(BuildContext context) {
    final total = _duration(type);
    final left = remaining ?? total;
    final progress = (left / total).clamp(0.0, 1.0);
    // The last stretch is the part that changes decisions, so it gets a
    // colour shift and a pulse rather than just a shorter arc.
    final warning = left <= 1.5;
    final tint = warning ? const Color(0xFFFF5252) : colorForType(type);

    return Semantics(
      label: '${type.displayName} active, '
          '${left.ceil()} second${left.ceil() == 1 ? '' : 's'} remaining',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: warning ? 1 : 0),
        duration: const Duration(milliseconds: 280),
        builder: (context, pulse, child) {
          return Transform.scale(
            scale: 1 + pulse * 0.04,
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1520).withOpacity(.82),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: tint.withOpacity((.55 + pulse * .45).clamp(0.0, 1.0)),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        tint.withOpacity((.30 + pulse * .25).clamp(0.0, 1.0)),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 9, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emblem with its radial countdown — the same art as the pickup.
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(32, 32),
                      painter: _PowerTimerPainter(
                        progress: progress,
                        warning: warning,
                        pulse: warning ? 1 : 0,
                      ),
                    ),
                    PowerUpEmblem(type: type, size: 22),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Naming the effect means the player never has to decode an
                  // icon to know what is currently changing their flight.
                  Text(
                    type.displayName.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: Colors.white,
                      fontSize: 8.5,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Linear drain: easier to read at a glance than an arc.
                  SizedBox(
                    width: 52,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(.16),
                        valueColor: AlwaysStoppedAnimation<Color>(tint),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _duration(PowerUpType type) {
    // Match the game loop's single source of truth so the radial countdown
    // divides by the same duration the burst was actually given. Every type
    // is timed now, including Shield and Decoy Clones.
    final duration =
        GameConfig.powerUpActiveDuration(type);
    return duration > 0 ? duration : 1.0;
  }

  static Color colorForType(PowerUpType type) {
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
      case PowerUpType.doubleScore:
        return const Color(0xFFE64A19);
      case PowerUpType.shrink:
        return const Color(0xFF7B1FA2);
      case PowerUpType.blackHole:
        return const Color(0xFF311B92);
      case PowerUpType.giant:
        return const Color(0xFFE65100);
    }
  }

}

/// Radial countdown drawn behind an active power-up's emblem.
class _PowerTimerPainter extends CustomPainter {
  const _PowerTimerPainter({
    required this.progress,
    required this.warning,
    required this.pulse,
  });

  final double progress;
  final bool warning;
  final double pulse;

  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromLTWH(1, 1, s.width - 2, s.height - 2);

    // Unfilled remainder, so the ring reads as a gauge rather than a stray arc.
    c.drawArc(
      rect,
      0,
      6.283,
      false,
      Paint()
        ..color = Colors.white.withOpacity(.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    c.drawArc(
      rect,
      -1.57,
      6.283 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = (warning ? Colors.redAccent : Colors.white)
            .withOpacity((warning ? .65 + pulse * .35 : .85).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PowerTimerPainter o) =>
      o.progress != progress || o.warning != warning || o.pulse != pulse;
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.game});
  final PaperFlightGame game;

  @override
  Widget build(BuildContext context) {
    final paused = game.phase == GamePhase.paused;
    final label = paused ? 'Resume flight' : 'Pause flight';

    void activate() {
      if (game.phase == GamePhase.playing) {
        game.pauseRun();
      } else if (game.phase == GamePhase.paused) {
        game.resumeRun();
      }
    }

    return Semantics(
      button: true,
      label: label,
      onTap: activate,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: activate,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xDD000000),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: AppColors.textLight,
              size: 24,
            ),
          ),
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
  Duration _lastVisualTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted || widget.game.phase != GamePhase.playing) return;
      // The ring is a small HUD affordance; 20 Hz is visually smooth and
      // avoids rebuilding it at 120 Hz on high-refresh devices.
      if (elapsed - _lastVisualTick < const Duration(milliseconds: 50)) return;
      _lastVisualTick = elapsed;
      setState(() {});
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

    void activate() {
      final fired = widget.game.triggerSnapBoost();
      if (fired && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }

    return Semantics(
      button: true,
      enabled: isPlaying && hasCharges,
      label: hasCharges
          ? 'Boost, $charges ${charges == 1 ? 'charge' : 'charges'} available'
          : 'Boost recharging, ${(progress * 100).round()} percent',
      onTap: isPlaying && hasCharges ? activate : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: isPlaying ? 1.0 : 0.45,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: isPlaying ? activate : null,
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
                      color: hasCharges ? Colors.white : const Color(0xFFD5DCE9),
                      size: 22,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      hasCharges ? 'BOOST' : 'WAIT',
                      style: TextStyle(
                        color: hasCharges ? Colors.white : const Color(0xFFD5DCE9),
                        fontSize: 9,
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
    final totalArc = (2 * math.pi - gap * maxCharges) / maxCharges;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // State color: 0 = Red pulse, 1 = Amber breathing, Max = Shimmering Gold
    final Color stateColor = charges == 0
        ? const Color(0xFFFF5252)
        : (charges < maxCharges ? const Color(0xFFFFA000) : const Color(0xFFFFD700));

    for (int i = 0; i < maxCharges; i++) {
      final start = -math.pi / 2 + i * (totalArc + gap);
      double sweep = totalArc;
      Paint? segPaint;
      bool draw = true;

      if (i < charges) {
        segPaint = Paint()
          ..color = stateColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
      } else if (i == charges && charges < maxCharges) {
        if (progress <= 0.01) {
          draw = false;
        } else {
          sweep = totalArc * progress.clamp(0.0, 1.0);
          segPaint = Paint()
            ..color = stateColor.withOpacity(0.5 + 0.35 * progress)
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
    return Semantics(
      label: 'Current area: ${biome.displayName}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xC7000000),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            biome.displayName.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFE3EAF5),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
