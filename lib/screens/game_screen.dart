import 'package:flame/game.dart';
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
import '../game/paper_flight_game.dart';
import '../game/overlays/hud_overlay.dart';
import '../models/run_result.dart';
import '../providers/game_session_provider.dart';
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

class _GameScreenState extends ConsumerState<GameScreen> {
  late PaperFlightGame _game;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _game = PaperFlightGame(
      ref: ref,
      mode: widget.args.mode,
      trialId: widget.args.trialId,
    );
  }

  @override
  void dispose() {
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
  Widget build(BuildContext context) {
    // Watch for game-over transition.
    ref.listen<GameSessionState>(gameSessionProvider, (prev, next) {
      if (next.phase != GamePhase.gameOver) return;
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

          // ── Flutter HUD ────────────────────────────────────────────────
          HudOverlay(game: _game),

          // ── Pause overlay ──────────────────────────────────────────────
          _PauseOverlay(game: _game),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // Delay one frame so GameWidget has time to mount the canvas.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _game.startRun();
      });
    }
  }

  void _navigateToGameOver(RunResult result, GameMode mode) {
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
      color: Colors.black.withOpacity(0.62),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: PaperCard(
            color: AppColors.paper,
            elevation: 2,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isZen ? 'PAUSED • ZEN' : 'PAUSED',
                  style: AppTypography.displayMedium
                      .copyWith(color: AppColors.paperInk, letterSpacing: 3),
                ),
                const SizedBox(height: 26),
                PaperButton(
                  label: 'Resume',
                  expand: true,
                  icon: const Icon(Icons.play_arrow, size: 20),
                  onPressed: () => game.resumeRun(),
                ),
                if (isZen) ...[
                  const SizedBox(height: 12),
                  PaperButton(
                    label: 'End Zen Flight',
                    expand: true,
                    color: AppColors.paperGreen,
                    icon: PaperIcon(PaperIconData.leaf,
                        size: 18, color: AppColors.paperInk),
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
                    game.resumeRun();
                    final exitRoute = switch (game.mode) {
                      GameMode.daily => AppRoutes.dailyFlight,
                      GameMode.trial => AppRoutes.trials,
                      GameMode.classic || GameMode.zen => AppRoutes.mainMenu,
                    };
                    Navigator.of(context).pushReplacementNamed(exitRoute);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
