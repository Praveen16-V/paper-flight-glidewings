import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_config.dart';

/// A single Blast Mode laser bolt, drawn as a bright beam from the plane to
/// the hazard it just destroyed.
///
/// The shot is resolved instantly in [BlastSystem] — this component is purely
/// the visual record of it, so it owns no gameplay state and cannot desync
/// from the kill it represents. It removes itself when it fades.
class LaserBoltComponent extends PositionComponent {
  LaserBoltComponent({
    required this.from,
    required this.to,
    this.color = const Color(0xFFFF1744),
  }) : super(priority: 6);

  /// Endpoints are world coordinates. The component itself stays anchored at
  /// the origin so its local canvas matches world space and the beam does not
  /// need to be re-projected each frame.
  final Vector2 from;
  final Vector2 to;
  final Color color;

  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= GameConfig.blastBoltLifetime) {
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / GameConfig.blastBoltLifetime).clamp(0.0, 1.0);
    // Snap to full brightness, then fall off — a beam should look like it was
    // already there rather than fading in.
    final fade = 1.0 - t;
    if (fade <= 0) return;

    final a = Offset(from.x, from.y);
    final b = Offset(to.x, to.y);

    // Outer glow.
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withOpacity(0.35 * fade)
        ..strokeWidth = 11 * fade
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Mid beam.
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withOpacity(0.85 * fade)
        ..strokeWidth = 5 * fade
        ..strokeCap = StrokeCap.round,
    );
    // White-hot core.
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Colors.white.withOpacity(0.95 * fade)
        ..strokeWidth = 2 * fade
        ..strokeCap = StrokeCap.round,
    );

    // Muzzle flare at the plane.
    canvas.drawCircle(
      a,
      9 * fade,
      Paint()
        ..color = Colors.white.withOpacity(0.75 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Impact star at the target.
    final spokes = Paint()
      ..color = Colors.white.withOpacity(0.9 * fade)
      ..strokeWidth = 2.2 * fade
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final ang = i * math.pi / 4 + _elapsed * 6;
      final r = 13 * (0.5 + t);
      canvas.drawLine(
        b + Offset(math.cos(ang) * r * .35, math.sin(ang) * r * .35),
        b + Offset(math.cos(ang) * r, math.sin(ang) * r),
        spokes,
      );
    }
  }
}
