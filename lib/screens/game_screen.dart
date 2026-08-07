import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
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
    _game.pauseEngine();
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('🌿 Zen Flight over', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${session.distanceMeters.toStringAsFixed(0)} m',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '$minutes:$secs • ${session.coinsThisRun} glide coins',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Zen flights are pure relaxation — coins are just for fun here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Back to menu'),
          ),
        ],
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
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isZen ? 'PAUSED • ZEN' : 'PAUSED',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 32),
            _PauseButton(
              label: 'Resume',
              icon: Icons.play_arrow,
              onTap: () => game.resumeRun(),
            ),
            const SizedBox(height: 16),
            if (isZen) ...[
              // Zen never ends in a crash — this is the only way out, and it
              // shows the quiet summary before returning to the menu.
              _PauseButton(
                label: 'End Zen Flight',
                icon: Icons.spa_outlined,
                onTap: () => game.endZenFlight(),
              ),
              const SizedBox(height: 16),
            ],
            _PauseButton(
              label: 'Quit',
              icon: Icons.home,
              onTap: () {
                if (isZen) {
                  game.endZenFlight();
                  return;
                }
                game.resumeRun();
                // Mode-aware exit: daily/trials return to their hub, classic
                // returns to the main menu.
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
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textLight, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textLight,
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
