import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../paper_flight_game.dart';
import '../effects/coin_feedback.dart';
import '../plane_component.dart';

/// A single power-up pickup, rendered as a floating 3D origami prism gift box.
/// Pooled and recycled by [PowerUpSpawner].
class PowerUpComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  PowerUpComponent({required this.type})
      : super(
          size: Vector2(38, 38),
          anchor: Anchor.center,
        );

  final PowerUpType type;
  CorruptedPowerUpType? corruptedType;
  bool get isCorrupted => corruptedType != null;

  bool _active = false;
  bool _collected = false;
  bool _recycleRequested = false;
  void Function(PowerUpComponent)? onRecycle;
  double _bobPhase = 0;
  double _glowPulse = 0;
  double _rotationAngle = 0;
  double _pickupAnimationElapsed = 0;

  static const double _pickupAnimationDuration = 0.22;

  void activate({
    required Vector2 spawnPosition,
    CorruptedPowerUpType? corruptedType,
    void Function(PowerUpComponent)? recycleCallback,
    int? animationSeed,
  }) {
    position = spawnPosition;
    this.corruptedType = corruptedType;
    final random = animationSeed == null ? math.Random() : math.Random(animationSeed);
    _bobPhase = random.nextDouble() * math.pi * 2;
    _glowPulse = 0;
    _rotationAngle = random.nextDouble() * math.pi * 2;
    _pickupAnimationElapsed = 0;
    _active = true;
    _collected = false;
    _recycleRequested = false;
    scale = Vector2.all(1);
    onRecycle = recycleCallback;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size * 0.85, position: size * 0.075));
  }

  void deactivate() {
    _active = false;
    _collected = false;
    corruptedType = null;
    _recycleRequested = false;
    _pickupAnimationElapsed = 0;
    scale = Vector2.all(1);
    onRecycle = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void update(double dt) {
    if (_collected) {
      _pickupAnimationElapsed += dt;
      final progress = (_pickupAnimationElapsed / _pickupAnimationDuration)
          .clamp(0.0, 1.0)
          .toDouble();
      scale = Vector2.all(1.0 + 0.8 * progress);
      if (progress >= 1.0) _requestRecycle();
      return;
    }
    if (!_active) return;

    position.y += gameRef.scrollSpeed * dt;
    _bobPhase += dt * 2.5;
    _glowPulse += dt * 4.0;
    _rotationAngle += dt * 1.8;

    // Subtle 3D floating hover
    position.y += math.sin(_bobPhase) * 0.40;

    if (position.y > GameConfig.powerUpRecycleY) {
      _active = false;
      _requestRecycle();
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
      _collect();
    }
  }

  void _collect() {
    _collected = true;
    _active = false;
    _pickupAnimationElapsed = 0;
    _applyEffect();
  }

  void _requestRecycle() {
    if (_recycleRequested) return;
    _recycleRequested = true;
    onRecycle?.call(this);
  }

  void _applyEffect() {
    final corrupt = corruptedType;
    if (corrupt != null) {
      gameRef.world.add(ColoredBurst(
        position: position.clone(),
        color: corrupt.color,
      ));
      gameRef.world.add(FloatingScoreText(
        position: position.clone(),
        text: corrupt.displayName.toUpperCase(),
        color: corrupt.color,
        fontSize: 18,
      ));
      gameRef.applyCorruptedPowerUp(corrupt);
      return;
    }
    spawnPowerUpFeedback(gameRef, position, type);
    gameRef.collectPowerUp(type);
  }

  // ── Render Floating 3D Origami Prism Gift Box ─────────────────────────────

  @override
  void render(Canvas canvas) {
    final glow = (math.sin(_glowPulse) * 0.5 + 0.5);
    final bgColor = corruptedType?.color ?? _bgColorForType(type);
    final iconColor = _iconColorForType(type);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // 1. Radial Glow Bloom
    final glowPaint = Paint()
      ..color = bgColor.withOpacity(0.30 + glow * 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(cx, cy), size.x * 0.65, glowPaint);

    // 2. Unfolding Origami Opening Animation on Pickup
    if (_collected) {
      final unfold = (_pickupAnimationElapsed / _pickupAnimationDuration).clamp(0.0, 1.0);
      _drawUnfoldingOrigamiBox(canvas, cx, cy, bgColor, unfold);
      return;
    }

    // 3. Floating 3D Origami Prism Faces
    final r = size.x * 0.42;
    final tilt = math.sin(_rotationAngle * 0.5) * 0.15;

    // Grounding drop shadow beneath the floating box (scales as it bobs).
    final hover = math.sin(_bobPhase).abs() * 0.12;
    final shadowW = r * 2.0 * (1.0 - hover);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + r * 1.6), width: shadowW, height: shadowW * 0.35),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);

    // Top Hexagonal / Diamond Facet (Lit Face)
    final topFacet = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.86, -r * 0.5)
      ..lineTo(0, 0)
      ..lineTo(-r * 0.86, -r * 0.5)
      ..close();

    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(bgColor, const Color(0xFFFFFFFF), 0.45)!,
          bgColor,
        ],
      ).createShader(Rect.fromCenter(center: Offset(0, -r * 0.5), width: r * 2, height: r))
      ..style = PaintingStyle.fill;
    canvas.drawPath(topFacet, topPaint);

    // Left Isometric Facet (Mid Tone)
    final leftFacet = Path()
      ..moveTo(-r * 0.86, -r * 0.5)
      ..lineTo(0, 0)
      ..lineTo(0, r)
      ..lineTo(-r * 0.86, r * 0.5)
      ..close();
    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          bgColor,
          Color.lerp(bgColor, const Color(0xFF000000), 0.25)!,
        ],
      ).createShader(Rect.fromCenter(center: Offset(-r * 0.43, r * 0.25), width: r, height: r * 1.5))
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftFacet, leftPaint);

    // Right Isometric Facet (Shadow Tone)
    final rightFacet = Path()
      ..moveTo(r * 0.86, -r * 0.5)
      ..lineTo(0, 0)
      ..lineTo(0, r)
      ..lineTo(r * 0.86, r * 0.5)
      ..close();
    final rightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(bgColor, const Color(0xFF000000), 0.15)!,
          Color.lerp(bgColor, const Color(0xFF000000), 0.42)!,
        ],
      ).createShader(Rect.fromCenter(center: Offset(r * 0.43, r * 0.25), width: r, height: r * 1.5))
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightFacet, rightPaint);

    // Fold Seams / Crease lines
    final seamPaint = Paint()
      ..color = Colors.white.withOpacity(0.40)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topFacet, seamPaint);
    canvas.drawPath(leftFacet, seamPaint);
    canvas.drawPath(rightFacet, seamPaint);

    // Specular catch-light on the lit top facet.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.25, -r * 0.62), width: r * 0.7, height: r * 0.3),
      Paint()..color = Colors.white.withOpacity(0.28),
    );

    // Golden Ribbon Cross-Wrap
    final goldRibbon = Paint()
      ..color = const Color(0xFFFFD54F).withOpacity(0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, -r), Offset(0, r), goldRibbon);
    canvas.drawLine(Offset(-r * 0.86, -r * 0.5), Offset(r * 0.86, r * 0.5), goldRibbon);

    // 4. Power-Up Icon Symbol
    _drawIcon(canvas, 0, 0, iconColor);
    if (isCorrupted) {
      final curse = Paint()
        ..color = const Color(0xFFFFEBEE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawLine(Offset(-r * .55, -r * .2), Offset(r * .55, r * .2), curse);
      canvas.drawLine(Offset(-r * .25, r * .55), Offset(r * .25, -r * .55), curse);
    }

    canvas.restore();
  }

  void _drawUnfoldingOrigamiBox(Canvas canvas, double cx, double cy, Color color, double t) {
    final spread = t * 24.0;
    final alpha = (1.0 - t).clamp(0.0, 1.0);
    final flapPaint = Paint()
      ..color = color.withOpacity(alpha * 0.85)
      ..style = PaintingStyle.fill;

    // 4 Splitting origami triangular flaps
    final flapUp = Path()..moveTo(cx, cy - spread)..lineTo(cx - 10, cy - spread + 10)..lineTo(cx + 10, cy - spread + 10)..close();
    final flapDown = Path()..moveTo(cx, cy + spread)..lineTo(cx - 10, cy + spread - 10)..lineTo(cx + 10, cy + spread - 10)..close();
    final flapLeft = Path()..moveTo(cx - spread, cy)..lineTo(cx - spread + 10, cy - 10)..lineTo(cx - spread + 10, cy + 10)..close();
    final flapRight = Path()..moveTo(cx + spread, cy)..lineTo(cx + spread - 10, cy - 10)..lineTo(cx + spread - 10, cy + 10)..close();

    canvas.drawPath(flapUp, flapPaint);
    canvas.drawPath(flapDown, flapPaint);
    canvas.drawPath(flapLeft, flapPaint);
    canvas.drawPath(flapRight, flapPaint);

    // Radiant particle burst
    final spark = Paint()..color = const Color(0xFFFFD54F).withOpacity(alpha);
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final dist = t * 32.0;
      canvas.drawCircle(Offset(cx + math.cos(a) * dist, cy + math.sin(a) * dist), 2.2 * (1.0 - t), spark);
    }
  }

  void _drawIcon(Canvas canvas, double cx, double cy, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case PowerUpType.shield:
        // Hexagonal shield badge (colorblind distinct silhouette)
        final hex = Path()
          ..moveTo(cx, cy - 9)
          ..lineTo(cx + 8, cy - 4.5)
          ..lineTo(cx + 8, cy + 4.5)
          ..lineTo(cx, cy + 9)
          ..lineTo(cx - 8, cy + 4.5)
          ..lineTo(cx - 8, cy - 4.5)
          ..close();
        canvas.drawPath(hex, paint);
        canvas.drawPath(hex, Paint()..color = Colors.white.withOpacity(0.9)..style = PaintingStyle.stroke..strokeWidth = 1.4);

      case PowerUpType.magnet:
        // Horseshoe U-shape with high-contrast notches
        final strokePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.square;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, cy - 1), width: 14, height: 14),
          math.pi,
          math.pi,
          false,
          strokePaint,
        );
        canvas.drawRect(Rect.fromLTWH(cx - 7, cy - 1, 3.5, 7), paint);
        canvas.drawRect(Rect.fromLTWH(cx + 3.5, cy - 1, 3.5, 7), paint);
        canvas.drawRect(Rect.fromLTWH(cx - 7, cy + 4, 3.5, 2.5), Paint()..color = Colors.white);
        canvas.drawRect(Rect.fromLTWH(cx + 3.5, cy + 4, 3.5, 2.5), Paint()..color = Colors.white);

      case PowerUpType.ghost:
        // Dome with 3 scalloped bottom waves & eye dots
        final body = Path()
          ..moveTo(cx - 8, cy + 2)
          ..lineTo(cx - 8, cy - 3)
          ..cubicTo(cx - 8, cy - 11, cx + 8, cy - 11, cx + 8, cy - 3)
          ..lineTo(cx + 8, cy + 2)
          ..lineTo(cx + 5, cy)
          ..lineTo(cx + 2, cy + 2)
          ..lineTo(cx - 1, cy)
          ..lineTo(cx - 4, cy + 2)
          ..lineTo(cx - 7, cy)
          ..close();
        canvas.drawPath(body, paint);
        canvas.drawPath(body, Paint()..color = Colors.white.withOpacity(0.85)..style = PaintingStyle.stroke..strokeWidth = 1.0);
        final eyePaint = Paint()..color = const Color(0xFF00363A);
        canvas.drawCircle(Offset(cx - 3.5, cy - 3), 1.3, eyePaint);
        canvas.drawCircle(Offset(cx + 3.5, cy - 3), 1.3, eyePaint);

      case PowerUpType.slowMo:
        // Clock circle with 12 hour tick notches & center hands
        final circlePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawCircle(Offset(cx, cy), 8, circlePaint);
        for (int i = 0; i < 4; i++) {
          final a = i * math.pi / 2;
          canvas.drawLine(
            Offset(cx + math.cos(a) * 6, cy + math.sin(a) * 6),
            Offset(cx + math.cos(a) * 8, cy + math.sin(a) * 8),
            Paint()..color = Colors.white..strokeWidth = 1.2,
          );
        }
        canvas.drawLine(Offset(cx, cy), Offset(cx + 4, cy - 3), circlePaint..strokeWidth = 1.8);
        canvas.drawLine(Offset(cx, cy), Offset(cx, cy - 5), circlePaint..strokeWidth = 1.8);

      case PowerUpType.coinRush:
        // Scalloped coin rim with "$" currency symbol
        canvas.drawCircle(Offset(cx, cy), 8.5, paint);
        canvas.drawCircle(Offset(cx, cy), 8.5, Paint()..color = const Color(0xFFFFD54F)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        final textP = TextPainter(
          text: const TextSpan(
            text: '\$',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF5D4037),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textP.paint(canvas, Offset(cx - textP.width / 2, cy - textP.height / 2));

      case PowerUpType.doubleScore:
        // "2X" energy symbol
        final textP = TextPainter(
          text: const TextSpan(
            text: '2X',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textP.paint(canvas, Offset(cx - textP.width / 2, cy - textP.height / 2));

      case PowerUpType.shrink:
        // Inward compression arrows
        final arr = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - 7, cy - 7), Offset(cx - 2, cy - 2), arr);
        canvas.drawLine(Offset(cx + 7, cy + 7), Offset(cx + 2, cy + 2), arr);
        canvas.drawLine(Offset(cx + 7, cy - 7), Offset(cx + 2, cy - 2), arr);
        canvas.drawLine(Offset(cx - 7, cy + 7), Offset(cx - 2, cy + 2), arr);
        canvas.drawCircle(Offset(cx, cy), 2.5, paint);

      case PowerUpType.windCaller:
        // 4-point compass rose
        final rose = Path()
          ..moveTo(cx, cy - 8)
          ..lineTo(cx + 2.5, cy - 2.5)
          ..lineTo(cx + 8, cy)
          ..lineTo(cx + 2.5, cy + 2.5)
          ..lineTo(cx, cy + 8)
          ..lineTo(cx - 2.5, cy + 2.5)
          ..lineTo(cx - 8, cy)
          ..lineTo(cx - 2.5, cy - 2.5)
          ..close();
        canvas.drawPath(rose, paint);

      case PowerUpType.decoyClone:
        // Dual mini paper planes
        final p1 = Path()..moveTo(cx - 4, cy - 5)..lineTo(cx - 1, cy + 4)..lineTo(cx - 4, cy + 2)..lineTo(cx - 7, cy + 4)..close();
        final p2 = Path()..moveTo(cx + 4, cy - 5)..lineTo(cx + 7, cy + 4)..lineTo(cx + 4, cy + 2)..lineTo(cx + 1, cy + 4)..close();
        canvas.drawPath(p1, paint);
        canvas.drawPath(p2, paint);

      case PowerUpType.blackHole:
        // Swirling vortex donut
        final hole = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2;
        canvas.drawCircle(Offset(cx, cy), 6, hole);
        canvas.drawCircle(Offset(cx, cy), 2, paint);

      case PowerUpType.turboDash:
        // Double chevron forward arrow
        final chev = Path()
          ..moveTo(cx - 6, cy + 4)..lineTo(cx, cy - 4)..lineTo(cx + 6, cy + 4)
          ..moveTo(cx - 6, cy)..lineTo(cx, cy - 8)..lineTo(cx + 6, cy);
        canvas.drawPath(chev, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0);
    }
  }

  static Color _bgColorForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return const Color(0xFF1565C0);
      case PowerUpType.magnet:
        return const Color(0xFF6A1B9A);
      case PowerUpType.ghost:
        return const Color(0xFF00838F);
      case PowerUpType.slowMo:
        return const Color(0xFF00695C);
      case PowerUpType.coinRush:
        return const Color(0xFFC77800);
      case PowerUpType.doubleScore:
        return const Color(0xFFE64A19);
      case PowerUpType.shrink:
        return const Color(0xFF7B1FA2);
      case PowerUpType.windCaller:
        return const Color(0xFF0097A7);
      case PowerUpType.decoyClone:
        return const Color(0xFF5C6BC0);
      case PowerUpType.blackHole:
        return const Color(0xFF311B92);
      case PowerUpType.turboDash:
        return const Color(0xFFFF3D00);
    }
  }

  static Color _iconColorForType(PowerUpType type) {
    return const Color(0xFFF7F9FC);
  }
}
