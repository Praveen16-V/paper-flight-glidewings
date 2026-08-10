import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
import '../../paper_flight_game.dart';
import '../effects/coin_feedback.dart';
import '../plane_component.dart';

/// Large thin origami paper ring gate (width 120).
/// Flying through the center gives a Perfect Clear (+1 boost charge & +5 combo notches).
class TunnelRingComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  TunnelRingComponent()
      : super(
          size: Vector2(120, 36),
          anchor: Anchor.center,
        );

  bool _active = false;
  bool _collected = false;
  void Function(TunnelRingComponent)? onRecycle;
  double _animTime = 0.0;
  double _ringPulse = 0.0;

  void activate({
    required Vector2 spawnPosition,
    void Function(TunnelRingComponent)? recycleCallback,
  }) {
    position = spawnPosition;
    _animTime = MathUtils.randomRange(0, math.pi * 2);
    _ringPulse = 0.0;
    _active = true;
    _collected = false;
    scale = Vector2.all(1);
    onRecycle = recycleCallback;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(size.x * 0.85, size.y * 0.9), position: Vector2(size.x * 0.075, size.y * 0.05)));
  }

  void deactivate() {
    _active = false;
    _collected = false;
    scale = Vector2.all(1);
    onRecycle = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void update(double dt) {
    if (_collected) {
      _ringPulse += dt * 4.0;
      scale = Vector2.all(1.0 + _ringPulse * 0.7);
      if (_ringPulse >= 1.0) {
        _active = false;
        onRecycle?.call(this);
      }
      return;
    }
    if (!_active) return;

    position.y += gameRef.scrollSpeed * dt;
    _animTime += dt;

    if (position.y > GameConfig.coinRecycleY + 40) {
      _active = false;
      onRecycle?.call(this);
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (!_active || _collected) return;
    if (other is PlaneComponent) {
      _passThrough(other);
    }
  }

  void _passThrough(PlaneComponent plane) {
    _collected = true;
    _active = false;
    _ringPulse = 0.0;

    // Check center clearance for Perfect Clear
    final dxFromCenter = (plane.position.x - position.x).abs();
    final isPerfectClear = dxFromCenter <= 26.0;

    if (isPerfectClear) {
      // Perfect Clear: +1 snap boost charge & +5 combo notches
      gameRef.scoringSystem.awardComboNotches(5.0);
      gameRef.inputManager.restoreSnapCharge(1);
      gameRef.gameFeelSystem.onCoinCollected(gameRef.scoringSystem.comboCount);

      final world = gameRef.world;
      world.add(ColoredBurst(position: position.clone(), color: const Color(0xFFFFD700)));
      world.add(
        FloatingScoreText(
          position: position.clone(),
          text: 'PERFECT CLEAR! +BOOST',
          color: const Color(0xFFFFD700),
          fontSize: 20,
        ),
      );
    } else {
      // Standard pass
      gameRef.scoringSystem.awardComboNotches(2.0);
      gameRef.gameFeelSystem.onCoinCollected(gameRef.scoringSystem.comboCount);

      final world = gameRef.world;
      world.add(ColoredBurst(position: position.clone(), color: const Color(0xFF4FC3F7)));
      world.add(
        FloatingScoreText(
          position: position.clone(),
          text: 'RING CLEAR! +2 COMBO',
          color: const Color(0xFF4FC3F7),
          fontSize: 16,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final rx = size.x * 0.48;
    final ry = size.y * 0.46;
    final pulse = (math.sin(_animTime * 5.0) * 0.5 + 0.5);

    // 1. Glowing Portal Aperture (Thin Torus Core)
    final portalPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(255, 215, 0, 0.40 + 0.25 * pulse),
          Color.fromRGBO(0, 229, 255, 0.20 + 0.15 * pulse),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.2, height: ry * 2.2))
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.0, height: ry * 2.0), portalPaint);

    // 2. Large Thin Torus Paper Ring
    final outerRing = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6;
    final innerHighlight = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final shadowBevel = Paint()
      ..color = const Color(0xFF4E342E).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), outerRing);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 1.0, cy - 1.0), width: rx * 2, height: ry * 2), innerHighlight);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 1.0, cy + 1.0), width: rx * 2, height: ry * 2), shadowBevel);

    // 3. Side Origami Brackets & Guidance Arrows
    final bracketPaint = Paint()..color = const Color(0xFFFFD54F)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - rx, cy), 3.5, bracketPaint);
    canvas.drawCircle(Offset(cx + rx, cy), 3.5, bracketPaint);

    // Center target indicator
    final target = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 0.7 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final chevY = cy + (pulse * 3.0 - 1.5);
    canvas.drawLine(Offset(cx - 6, chevY - 3), Offset(cx, chevY + 4), target);
    canvas.drawLine(Offset(cx + 6, chevY - 3), Offset(cx, chevY + 4), target);
  }
}
