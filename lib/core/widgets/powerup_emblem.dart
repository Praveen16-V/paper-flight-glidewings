import 'package:flutter/material.dart';

import '../../game/components/powerups/powerup_art.dart';
import '../enums/game_enums.dart';

/// Renders a power-up's emblem in the widget layer using the exact same
/// painter the world pickup uses.
///
/// This is the point of the shared art: the horseshoe magnet the player grabs
/// in the sky is pixel-for-pixel the horseshoe magnet that then appears on the
/// HUD, so the link between "what I picked up" and "what is active" needs no
/// learning.
class PowerUpEmblem extends StatelessWidget {
  const PowerUpEmblem({
    super.key,
    required this.type,
    this.size = 24,
    this.phase = 0,
  });

  final PowerUpType type;
  final double size;

  /// Animation phase. Static HUD chips can leave this at 0.
  final double phase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PowerUpEmblemPainter(type: type, phase: phase),
      ),
    );
  }
}

class _PowerUpEmblemPainter extends CustomPainter {
  const _PowerUpEmblemPainter({required this.type, required this.phase});

  final PowerUpType type;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    PowerUpArt.draw(canvas, type, size.width * 0.44, phase);
  }

  @override
  bool shouldRepaint(covariant _PowerUpEmblemPainter old) =>
      old.type != type || old.phase != phase;
}
