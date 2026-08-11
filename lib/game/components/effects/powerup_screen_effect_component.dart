import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../providers/game_session_provider.dart';
import '../../paper_flight_game.dart';

/// Screen-space-style compositing for the most perception-altering power-ups.
///
/// The project deliberately stays asset-light, so this uses procedural Canvas
/// passes rather than requiring GPU shader assets. It remains isolated from
/// PlaneComponent so an eventual Flame FragmentProgram implementation can swap
/// in without touching gameplay state or HUD contracts.
class PowerUpScreenEffectComponent extends PositionComponent
    with HasGameRef<PaperFlightGame> {
  PowerUpScreenEffectComponent()
      : super(size: Vector2(GameConfig.designWidth, GameConfig.designHeight));

  double _time = 0;

  @override
  void update(double dt) {
    if (gameRef.phase == GamePhase.playing) _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final session = gameRef.ref.read(gameSessionProvider);
    final active = session.activePowerUps;
    if (active.contains(PowerUpType.ghost)) _drawGhostAberration(canvas);
    if (active.contains(PowerUpType.slowMo)) _drawSlowMoTimeField(canvas);
    if (active.contains(PowerUpType.blackHole)) _drawBlackHoleLensing(canvas);
  }

  void _drawGhostAberration(Canvas canvas) {
    final shift = 3.0 + math.sin(_time * 11.0) * 1.8;
    final cyan = Paint()
      ..color = const Color(0x2200E5FF)
      ..style = PaintingStyle.fill;
    final magenta = Paint()
      ..color = const Color(0x22E040FB)
      ..style = PaintingStyle.fill;

    // Offset fringes at the viewport boundaries mimic chromatic splitting
    // without altering collision-space or Flutter HUD text.
    canvas.drawRect(Rect.fromLTWH(-shift, 0, 10, size.y), cyan);
    canvas.drawRect(Rect.fromLTWH(size.x - 10 + shift, 0, 10, size.y), magenta);
    final noise = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = .8;
    for (var i = 0; i < 8; i++) {
      final y = ((_time * 95 + i * 113) % (size.y + 30)) - 15;
      canvas.drawLine(Offset(0, y), Offset(size.x, y + math.sin(i + _time) * 2), noise);
    }
  }

  void _drawSlowMoTimeField(Canvas canvas) {
    final center = gameRef.plane.position.toOffset();
    final pulse = .55 + math.sin(_time * 3) * .18;
    final ring = Paint()
      ..color = Color.fromRGBO(128, 222, 234, .17 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      final radius = 52.0 + i.toDouble() * 42 + ((_time * 22) % 42);
      canvas.drawCircle(center, radius, ring);
    }

    // Radial time trails read as a slow-field around the craft rather than
    // generic speed lines.
    final trail = Paint()
      ..color = const Color(0x3364FFDA)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final a = i.toDouble() * math.pi * 2 / 10 + _time * .22;
      final inner = 38.0 + math.sin(_time + i) * 6;
      final outer = inner + 24.0 + (i % 3).toDouble() * 8;
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * inner, center.dy + math.sin(a) * inner),
        Offset(center.dx + math.cos(a) * outer, center.dy + math.sin(a) * outer),
        trail,
      );
    }
  }

  void _drawBlackHoleLensing(Canvas canvas) {
    final center = gameRef.plane.position.toOffset();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (var i = 0; i < 3; i++) {
      ring.color = i.isEven
          ? const Color(0x665E35B1)
          : const Color(0x6600E5FF);
      final radius = 62.0 + i.toDouble() * 36 + math.sin(_time * 4 + i.toDouble()) * 5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _time * (1.2 + i.toDouble() * .35),
        math.pi * 1.55,
        false,
        ring,
      );
    }

    // Curved edge guides simulate background light bending toward the vortex.
    final lens = Paint()
      ..color = const Color(0x225E35B1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 5; i++) {
      final y = i.toDouble() * size.y / 4;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(center.dx, center.dy + (y - center.dy) * .28,
            size.x, y);
      canvas.drawPath(path, lens);
    }
  }
}
