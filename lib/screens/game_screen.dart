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

/// Hosts the Flame GameWidget + Flutter HUD overlay + pause overlay.
///
/// Uses GameWidget.controlled so we own the game lifecycle:
///   - Create game when screen is first built.
///   - Call game.startRun() after first frame.
///   - Listen to gameSessionProvider to navigate to game-over screen.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late PaperFlightGame _game;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _game = PaperFlightGame(ref: ref);
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
      if (next.phase == GamePhase.gameOver && next.lastRunResult != null) {
        _navigateToGameOver(next.lastRunResult!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Flame game canvas ──────────────────────────────────────────
          GameWidget(
            game: _game,
            backgroundBuilder: (_) => Container(color: AppColors.background),
            loadingBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
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

  void _navigateToGameOver(RunResult result) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.gameOver,
      arguments: GameOverArgs(result: result),
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

    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
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
            _PauseButton(
              label: 'Quit',
              icon: Icons.home,
              onTap: () {
                game.resumeRun();
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.mainMenu);
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
