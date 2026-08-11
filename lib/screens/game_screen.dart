import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/how_to_play_dialog.dart';
import '../core/widgets/mode_intro_overlay.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../core/widgets/stat_counter.dart';
import '../game/paper_flight_game.dart';
import '../game/overlays/hud_overlay.dart';
import '../l10n/app_localizations.dart';
import '../models/run_result.dart';
import '../providers/game_session_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analytics_service.dart';
import '../services/frame_performance_monitor.dart';
import '../services/onboarding_service.dart';
import 'game_over_screen.dart';
import 'trial_results_screen.dart';

/// Route args for the game screen — picks the mode (Task 8).
class GameScreenArgs {
  const GameScreenArgs({this.mode = GameMode.classic, this.trialId});
  final GameMode mode;
  final int? trialId;
}

/// Hosts the Flame GameWidget + Flutter HUD overlay + pause overlay.
///
/// Uses GameWidget.controlled so we own the game lifecycle:
///   - Create game when screen is first built.
///   - Call game.startRun() after first frame.
///   - Listen to gameSessionProvider to navigate to the mode-appropriate
///     results screen (game-over / trial results / zen summary).
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.args = const GameScreenArgs()});
  final GameScreenArgs args;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late PaperFlightGame _game;
  late FramePerformanceMonitor _performanceMonitor;
  bool _started = false;
  bool _startScheduled = false;
  bool _showModeIntro = false;
  bool _diagnosticsReported = false;

  /// A game-over session can continue publishing HUD timer updates while the
  /// results route is being pushed (for example, when a timed power-up is
  /// active at the moment of impact). Navigation must happen only for the
  /// actual playing -> gameOver edge; otherwise every one of those updates
  /// pushes another results route and the screen appears to flicker.
  bool _resultsNavigationStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = PaperFlightGame(
      ref: ref,
      mode: widget.args.mode,
      trialId: widget.args.trialId,
    );
    _performanceMonitor = FramePerformanceMonitor(
      mode: widget.args.mode,
      trialId: widget.args.trialId,
    );
    _showModeIntro =
        !OnboardingService.instance.hasSeenModeTip(widget.args.mode);
    if (_showModeIntro) {
      AnalyticsService.instance.logOnboarding(
        action: 'mode_tip_shown',
        surface: 'game_preflight',
        mode: widget.args.mode,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_started && !_resultsNavigationStarted &&
        (_game.phase == GamePhase.playing ||
            _game.phase == GamePhase.paused)) {
      _game.abandonRun(reason: 'game_screen_disposed');
    }
    final diagnosticsOutcome =
        _resultsNavigationStarted ? 'completed' : 'abandoned';
    _performanceMonitor.stop(outcome: diagnosticsOutcome);
    _reportRuntimeDiagnostics(diagnosticsOutcome);

    // Do NOT manually call _game.dispose() here.
    //
    // Flutter disposes parent StatefulWidget (GameScreen) BEFORE its children
    // (GameWidget). If we call _game.dispose() here, it sets _disposed=true
    // and runs _releaseResources(cascadeChildren:false). Then when GameWidget
    // is disposed, it calls game.onRemove() which runs
    // _releaseResources(cascadeChildren:true) but returns early due to the
    // _disposed guard — leaving the world's children (plane, obstacles,
    // spawners, etc.) never removed, causing resource leaks that accumulate
    // over multiple plays.
    //
    // The correct lifecycle is: GameWidget.dispose() -> game.onRemove() ->
    // _releaseResources(cascadeChildren:true) which properly cleans up
    // everything including cascading to all world children.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (_started && _game.phase == GamePhase.playing) {
      _game.pauseRun();
      AnalyticsService.instance.logEvent(
        'game_auto_paused',
        params: {
          'mode': widget.args.mode.name,
          'lifecycle_state': state.name,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for the playing -> gameOver edge. The game can still publish
    // provider changes after it enters gameOver (power-up countdowns are the
    // usual example), so checking only `next.phase` would enqueue a new route
    // on every update and make the results screen flicker.
    ref.listen<GameSessionState>(gameSessionProvider, (prev, next) {
      if (!mounted || _resultsNavigationStarted) return;
      if (next.phase != GamePhase.gameOver ||
          prev?.phase == GamePhase.gameOver) {
        return;
      }

      _resultsNavigationStarted = true;
      final diagnosticsOutcome = _performanceOutcome(next);
      _performanceMonitor.stop(outcome: diagnosticsOutcome);
      _reportRuntimeDiagnostics(diagnosticsOutcome);
      if (next.mode == GameMode.trial && next.trialOutcome != null) {
        _navigateToTrialResults(next.trialOutcome!);
        return;
      }
      if (next.mode == GameMode.zen) {
        _showZenSummary();
        return;
      }
      if (next.lastRunResult != null) {
        _navigateToGameOver(next.lastRunResult!, next.mode);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Flame game canvas ──────────────────────────────────────────
          Positioned.fill(
            child: GameWidget(
              game: _game,
              backgroundBuilder: (_) => Container(color: AppColors.background),
              loadingBuilder: (_) => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ),

          // Keep the idle canvas clean while the one-time pre-flight card is
          // visible. The Daily attempt is not consumed until Start is tapped.
          if (!_showModeIntro && _started) HudOverlay(game: _game),
          if (!_showModeIntro && _started) _PauseOverlay(game: _game),

          if (_showModeIntro)
            ModeIntroOverlay(
              mode: widget.args.mode,
              controlScheme: ref.watch(settingsProvider).controlScheme,
              detail: widget.args.mode == GameMode.trial
                  ? _game.trial?.objective
                  : null,
              onStart: _dismissModeIntroAndStart,
              onOpenGuide: () => showHowToPlayDialog(
                context,
                surface: 'mode_intro_${widget.args.mode.name}',
              ),
            ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_showModeIntro) _scheduleRunStart();
  }

  void _scheduleRunStart() {
    if (_started || _startScheduled) return;
    _startScheduled = true;
    // Delay one frame so GameWidget has mounted its canvas and systems.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (!mounted || _started || _showModeIntro) return;
      _started = true;
      _game.startRun();
      _performanceMonitor.start();
      if (mounted) setState(() {});
    });
  }

  Future<void> _dismissModeIntroAndStart() async {
    await OnboardingService.instance.markModeTipSeen(widget.args.mode);
    AnalyticsService.instance.logOnboarding(
      action: 'mode_tip_completed',
      surface: 'game_preflight',
      mode: widget.args.mode,
    );
    if (!mounted) return;
    setState(() => _showModeIntro = false);
    _scheduleRunStart();
  }

  void _reportRuntimeDiagnostics(String outcome) {
    if (!_started || _diagnosticsReported || _game.isDisposed) return;
    _diagnosticsReported = true;
    unawaited(
      AnalyticsService.instance.logRuntimeDiagnostics(
        mode: widget.args.mode,
        outcome: outcome,
        snapshot: _game.runtimeDiagnostics,
      ),
    );
  }

  String _performanceOutcome(GameSessionState session) {
    if (session.mode == GameMode.trial) {
      return session.trialOutcome?.completed == true
          ? 'trial_completed'
          : 'trial_failed';
    }
    if (session.mode == GameMode.zen) return 'zen_completed';
    return 'crashed';
  }

  void _navigateToGameOver(RunResult result, GameMode mode) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.gameOver,
      arguments: GameOverArgs(
        result: result,
        mode: mode,
        dailySeed: mode == GameMode.daily ? _game.dailySeed : null,
      ),
    );
  }

  void _navigateToTrialResults(TrialOutcome outcome) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.trialResult,
      arguments: TrialResultArgs(outcome: outcome),
    );
  }

  /// Zen Flight never "crashes" — ending the flight shows a quiet summary
  /// and returns to the menu.
  Future<void> _showZenSummary() async {
    final session = ref.read(gameSessionProvider);
    final minutes = session.runTimeSeconds ~/ 60;
    final secs = (session.runTimeSeconds % 60).toStringAsFixed(0).padLeft(2, '0');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: PaperCard(
          color: AppColors.paperGreen,
          elevation: 2,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          dogEar: const DogEar(
            label: 'ZEN',
            color: AppColors.success,
            size: 56,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PaperIcon(PaperIconData.leaf,
                  size: 40, color: AppColors.success),
              const SizedBox(height: 10),
              Text('Zen Flight over',
                  style: AppTypography.headline
                      .copyWith(color: AppColors.paperInk)),
              const SizedBox(height: 18),
              StatCounter(
                session.distanceMeters,
                suffix: ' m',
                style: AppTypography.score
                    .copyWith(color: AppColors.paperInk, fontSize: 36),
              ),
              const SizedBox(height: 6),
              Text(
                '$minutes:$secs • ${session.coinsThisRun} glide coins',
                style: AppTypography.caption
                    .copyWith(color: AppColors.paperInkSoft),
              ),
              const SizedBox(height: 14),
              Text(
                'Zen flights are pure relaxation — coins are just for fun here.',
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: AppColors.paperInkSoft, fontSize: 12),
              ),
              const SizedBox(height: 20),
              PaperButton(
                label: 'Back to menu',
                expand: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends ConsumerWidget {
  const _PauseOverlay({required this.game});

  final PaperFlightGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(gameSessionProvider.select((s) => s.phase));
    if (phase != GamePhase.paused) return const SizedBox.shrink();

    final isZen = game.mode == GameMode.zen;

    return Container(
      color: Colors.black.withOpacity(0.68),
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: PaperCard(
                color: AppColors.paper,
                elevation: 2,
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isZen ? 'PAUSED • ZEN' : 'PAUSED',
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.paperInk,
                        letterSpacing: 3,
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 14),
                      _RuntimeDiagnosticsPanel(game: game),
                    ],
                    const SizedBox(height: 26),
                    PaperButton(
                      label: 'Resume',
                      expand: true,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      onPressed: () => game.resumeRun(),
                    ),
                    const SizedBox(height: 12),
                    PaperButton(
                      label: context.l10n.text('pause.howToPlay'),
                      expand: true,
                      color: AppColors.paperBlue,
                      icon: const Icon(Icons.help_outline_rounded, size: 20),
                      onPressed: () => showHowToPlayDialog(
                        context,
                        surface: 'pause_${game.mode.name}',
                      ),
                    ),
                    if (isZen) ...[
                      const SizedBox(height: 12),
                      PaperButton(
                        label: 'End Zen Flight',
                        expand: true,
                        color: AppColors.paperGreen,
                        icon: const PaperIcon(
                          PaperIconData.leaf,
                          size: 18,
                          color: AppColors.paperInk,
                        ),
                        onPressed: () => game.endZenFlight(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    PaperButton(
                      label: 'Quit',
                      expand: true,
                      color: AppColors.paperWarm,
                      textColor: AppColors.paperInk,
                      icon: const Icon(Icons.home, size: 20),
                      onPressed: () {
                        if (isZen) {
                          game.endZenFlight();
                          return;
                        }
                        game.abandonRun(reason: 'pause_menu_quit');
                        final exitRoute = switch (game.mode) {
                          GameMode.daily => AppRoutes.dailyFlight,
                          GameMode.trial => AppRoutes.trials,
                          GameMode.classic || GameMode.zen =>
                            AppRoutes.mainMenu,
                        };
                        Navigator.of(context).pushReplacementNamed(exitRoute);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Debug-only pause-card view for replay/pool health during a live soak run.
class _RuntimeDiagnosticsPanel extends StatelessWidget {
  const _RuntimeDiagnosticsPanel({required this.game});

  final PaperFlightGame game;

  @override
  Widget build(BuildContext context) {
    final snapshot = game.runtimeDiagnostics;
    final shortFingerprint = snapshot.replay.fingerprint.length > 18
        ? snapshot.replay.fingerprint.substring(
            snapshot.replay.fingerprint.length - 18,
          )
        : snapshot.replay.fingerprint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF18222B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentAlt.withOpacity(.65)),
      ),
      child: DefaultTextStyle(
        style: AppTypography.statSmall.copyWith(
          color: const Color(0xFFE1F5FE),
          fontSize: 10,
          height: 1.45,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEV DIAGNOSTICS',
              style: AppTypography.overline.copyWith(
                color: AppColors.accentAlt,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
            Text('trace $shortFingerprint • ${snapshot.replay.eventCount} events'),
            Text(
              'active ${snapshot.activeEntityCount} • pools peak '
              '${snapshot.poolPeakInUse} • rejected '
              '${snapshot.poolRejectedReleases}',
            ),
            Text(
              'difficulty ${(snapshot.dynamicDifficulty * 100).round()}% • '
              'discarded ${snapshot.poolDiscarded}',
            ),
          ],
        ),
      ),
    );
  }
}
