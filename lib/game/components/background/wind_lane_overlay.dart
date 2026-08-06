import 'dart:ui';

import 'package:flame/components.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../paper_flight_game.dart';

/// Subtle vertical lane tint / streak indicators so players can read wind
/// columns as they approach (GDD §4 — wind is a systemic mechanic).
class WindLaneOverlay extends Component with HasGameRef<PaperFlightGame> {
  WindLaneOverlay() {
    priority = -50;
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.phase != GamePhase.playing &&
        gameRef.phase != GamePhase.paused) {
      return;
    }

    final types = gameRef.windSystem.laneTypes;
    final intensities = gameRef.windSystem.laneIntensities;
    final laneW = GameConfig.designWidth / GameConfig.windLaneCount;
    final h = GameConfig.designHeight;

    for (int i = 0; i < types.length; i++) {
      final type = types[i];
      final intensity = intensities[i];
      if (type == WindType.calm && intensity < 0.15) continue;

      final color =
          _colorFor(type).withValues(alpha: (0.04 + intensity * 0.10).clamp(0.0, 1.0));
      final paint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromLTWH(i * laneW, 0, laneW, h),
        paint,
      );

      // Direction chevrons for lateral wind.
      if (type == WindType.leftPush || type == WindType.rightPush) {
        final chevron = Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final cx = i * laneW + laneW / 2;
        final dir = type == WindType.rightPush ? 1.0 : -1.0;
        for (double y = 40; y < h; y += 80) {
          canvas.drawLine(
            Offset(cx - 6 * dir, y - 5),
            Offset(cx + 6 * dir, y),
            chevron,
          );
          canvas.drawLine(
            Offset(cx - 6 * dir, y + 5),
            Offset(cx + 6 * dir, y),
            chevron,
          );
        }
      }

      // Thermal up arrows.
      if (type == WindType.thermal) {
        final up = Paint()
          ..color = const Color(0x44FFCC80)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final cx = i * laneW + laneW / 2;
        for (double y = 60; y < h; y += 90) {
          canvas.drawLine(Offset(cx, y + 8), Offset(cx, y - 8), up);
          canvas.drawLine(Offset(cx - 5, y - 2), Offset(cx, y - 8), up);
          canvas.drawLine(Offset(cx + 5, y - 2), Offset(cx, y - 8), up);
        }
      }
    }
  }

  Color _colorFor(WindType type) {
    switch (type) {
      case WindType.calm:
        return const Color(0x00000000);
      case WindType.leftPush:
      case WindType.rightPush:
        return const Color(0xFF81D4FA);
      case WindType.turbulent:
        return const Color(0xFFFFAB91);
      case WindType.thermal:
        return const Color(0xFFFFCC80);
    }
  }
}
