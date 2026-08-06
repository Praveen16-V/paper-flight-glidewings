import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
import '../../providers/save_data_provider.dart';
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

    return SafeArea(
      child: Stack(
        children: [
          // ── Top bar: score + coins ──────────────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ScoreDisplay(
                  score: session.score,
                  isNew: session.lastRunResult?.isNewHighScore ?? false,
                ),
                _CoinDisplay(coins: session.coinsThisRun),
              ],
            ),
          ),

          // ── Distance meter ─────────────────────────────────────────────
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: _DistanceDisplay(meters: session.distanceMeters),
            ),
          ),

          // ── Combo strip ────────────────────────────────────────────────
          if (session.comboCount >= 3)
            Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: Center(
                child: _ComboDisplay(
                  count: session.comboCount,
                  multiplier: session.comboMultiplier,
                ),
              ),
            ),

          // ── Active power-up icons (bottom-left) ────────────────────────
          Positioned(
            bottom: 100,
            left: 16,
            child: _PowerUpBar(activePowerUps: session.activePowerUps),
          ),

          // ── Pause button ───────────────────────────────────────────────
          Positioned(
            top: 12,
            right: 16,
            child: _PauseButton(game: game),
          ),

          // ── Biome label (fades in on transition) ───────────────────────
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
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
              color: AppColors.textLight,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
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
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: AppColors.coinGold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(
              color: AppColors.coinGold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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

class _ComboDisplay extends StatelessWidget {
  const _ComboDisplay({required this.count, required this.multiplier});
  final int count;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
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
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PowerUpBar extends StatelessWidget {
  const _PowerUpBar({required this.activePowerUps});
  final Set<PowerUpType> activePowerUps;

  @override
  Widget build(BuildContext context) {
    if (activePowerUps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: activePowerUps.map((type) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _PowerUpIcon(type: type),
        );
      }).toList(),
    );
  }
}

class _PowerUpIcon extends StatelessWidget {
  const _PowerUpIcon({required this.type});
  final PowerUpType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _colorForType(type),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Center(
        child: Text(
          _emojiForType(type),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Color _colorForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return const Color(0xFF1565C0);
      case PowerUpType.magnet:
        return const Color(0xFF6A1B9A);
      case PowerUpType.turboGust:
        return const Color(0xFFE65100);
      case PowerUpType.slowMo:
        return const Color(0xFF00695C);
      case PowerUpType.secondWind:
        return const Color(0xFF1B5E20);
    }
  }

  String _emojiForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return '🛡';
      case PowerUpType.magnet:
        return '🧲';
      case PowerUpType.turboGust:
        return '⚡';
      case PowerUpType.slowMo:
        return '🌀';
      case PowerUpType.secondWind:
        return '💨';
    }
  }
}

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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.hudBackground,
          borderRadius: BorderRadius.circular(20),
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
        letterSpacing: 2.5,
      ),
    );
  }
}
