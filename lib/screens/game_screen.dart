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
import '../providers/save_data_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analytics_service.dart';
import 'game_over_screen.dart';

/// Hosts the Flame GameWidget + Flutter HUD overlay + pause overlay.
///
/// Route args:
///   - null / default → fresh run
///   - [GameScreenArgs.revive] → continue last run via game.revive()
///   - [GameScreenArgs.withShield] → start with free shield (shop ad reward)
class GameScreenArgs {
  const GameScreenArgs({
    this.revive = false,
    this.withShield = false,
  });

  final bool revive;
  final bool withShield;
}

/// Hosts the Flame GameWidget + Flutter HUD overlay + pause overlay.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.args});

  final GameScreenArgs? args;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late PaperFlightGame _game;
  bool _started = false;
  bool _navigatingAway = false;

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
      if (!_navigatingAway &&
          next.phase == GamePhase.gameOver &&
          next.lastRunResult != null) {
        _navigateToGameOver(next.lastRunResult!);
      }
    });

    // Keep input manager in sync if settings change mid-run (e.g. via pause menu).
    ref.listen(settingsProvider, (prev, next) {
      if (!_game.isLoaded) return;
      _game.inputManager.updateSensitivity(next.tiltSensitivity);
      _game.inputManager.updateControlScheme(next.controlScheme);
    });

    final controlScheme =
        ref.watch(settingsProvider.select((s) => s.controlScheme));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Flame game canvas ──────────────────────────────────────────
          Positioned.fill(
            child: GameWidget(
              game: _game,
              backgroundBuilder: (_) =>
                  Container(color: AppColors.background),
              loadingBuilder: (_) => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ),

          // ── Touch-zone guides (alt control scheme) ─────────────────────
          if (controlScheme == ControlScheme.touchZones)
            const _TouchZoneGuides(),

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _beginRun();
      });
    }
  }

  Future<void> _beginRun() async {
    final args = widget.args;
    final save = ref.read(saveDataProvider);
    final session = ref.read(gameSessionProvider);

    // Wait until Flame has finished onLoad so systems/plane exist.
    if (!_game.isLoaded) {
      await _game.loaded;
    }
    if (!mounted) return;

    if (args?.revive == true && session.crashSnapshot != null) {
      final snap = session.crashSnapshot!;
      _game.startRunFromSnapshot(snap);
    } else {
      final withShield =
          (args?.withShield ?? false) || save.pendingStartShield;
      if (save.pendingStartShield) {
        ref.read(saveDataProvider.notifier).clearPendingStartShield();
      }
      _game.startRun(withShield: withShield);
      AnalyticsService.instance.logRunStarted();
    }
  }

  void _navigateToGameOver(RunResult result) {
    if (_navigatingAway || !mounted) return;
    _navigatingAway = true;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.gameOver,
      arguments: GameOverArgs(result: result),
    );
  }
}

/// Subtle left/right zone indicators for touch-zone control scheme.
class _TouchZoneGuides extends StatelessWidget {
  const _TouchZoneGuides();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Row(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white.withOpacity(0.25),
                  size: 28,
                ),
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.25),
                  size: 28,
                ),
              ),
            ),
          ],
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
