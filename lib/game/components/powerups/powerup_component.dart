import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
import '../../../providers/game_session_provider.dart';
import '../../paper_flight_game.dart';
import '../effects/coin_feedback.dart';
import '../plane_component.dart';

/// A single power-up pickup. Pooled and recycled by [PowerUpSpawner].
class PowerUpComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  PowerUpComponent({required this.type})
      : super(
          size: Vector2(36, 36),
          anchor: Anchor.center,
        );

  final PowerUpType type;

  bool _active = false;
  bool _collected = false;
  bool _recycleRequested = false;
  void Function(PowerUpComponent)? onRecycle;
  double _bobPhase = 0;
  double _glowPulse = 0;
  double _pickupAnimationElapsed = 0;

  static const double _pickupAnimationDuration = 0.2;

  void activate({
    required Vector2 spawnPosition,
    void Function(PowerUpComponent)? recycleCallback,
  }) {
    position = spawnPosition;
    _bobPhase = MathUtils.randomRange(0, math.pi * 2);
    _glowPulse = 0;
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
    _recycleRequested = false;
    _pickupAnimationElapsed = 0;
    scale = Vector2.all(1);
    onRecycle = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void update(double dt) {
    // Do not attach an OpacityEffect here. PowerUpComponent renders itself and
    // is not a HasPaint component; applying that effect causes a runtime type
    // error exactly when a power-up is collected, which stops the game loop.
    if (_collected) {
      _pickupAnimationElapsed += dt;
      final progress = (_pickupAnimationElapsed / _pickupAnimationDuration)
          .clamp(0.0, 1.0)
          .toDouble();
      scale = Vector2.all(1.0 + 0.6 * progress);
      if (progress >= 1.0) _requestRecycle();
      return;
    }
    if (!_active) return;

    position.y += gameRef.scrollSpeed * dt;
    _bobPhase += dt * 2.5;
    _glowPulse += dt * 4.0;

    // Subtle hover
    position.y += math.sin(_bobPhase) * 0.35;

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

    // The pickup's pop/fade is handled by this component's update/render
    // methods. Keeping it self-contained avoids applying paint effects to a
    // custom-rendered PositionComponent.
    _pickupAnimationElapsed = 0;
    _applyEffect();
  }

  void _requestRecycle() {
    if (_recycleRequested) return;
    _recycleRequested = true;
    onRecycle?.call(this);
  }

  void _applyEffect() {
    final notifier = gameRef.ref.read(gameSessionProvider.notifier);

    // Announce the pickup with a colored burst + banner before applying it.
    spawnPowerUpFeedback(gameRef, position, type);

    switch (type) {
      case PowerUpType.shield:
        // Absorbs exactly one hit — no timer; consumed on impact.
        notifier.activatePowerUp(PowerUpType.shield);
      case PowerUpType.magnet:
        notifier.activatePowerUp(PowerUpType.magnet);
        Future.delayed(
          Duration(milliseconds: (GameConfig.magnetDuration * 1000).toInt()),
          () => notifier.deactivatePowerUp(PowerUpType.magnet),
        );
      case PowerUpType.ghost:
        // Phase through every obstacle — the big "fly through the wall" moment.
        notifier.activatePowerUp(PowerUpType.ghost);
        Future.delayed(
          Duration(milliseconds: (GameConfig.ghostDuration * 1000).toInt()),
          () => notifier.deactivatePowerUp(PowerUpType.ghost),
        );
      case PowerUpType.slowMo:
        notifier.activatePowerUp(PowerUpType.slowMo);
        gameRef.applySlowMo(GameConfig.slowMoDuration);
      case PowerUpType.coinRush:
        // 2× coin value for the duration, plus an immediate coin shower.
        notifier.activatePowerUp(PowerUpType.coinRush);
        gameRef.beginCoinRush();
        Future.delayed(
          Duration(milliseconds: (GameConfig.coinRushDuration * 1000).toInt()),
          () => notifier.deactivatePowerUp(PowerUpType.coinRush),
        );
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final glow = (math.sin(_glowPulse) * 0.5 + 0.5); // 0–1
    final bgColor = _bgColorForType(type);
    final iconColor = _iconColorForType(type);

    // Glowing background circle
    final glowPaint = Paint()
      ..color = bgColor.withOpacity(0.25 + glow * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 + 4,
      glowPaint,
    );

    // Solid background
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    // Icon
    _drawIcon(canvas, iconColor);
  }

  void _drawIcon(Canvas canvas, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = size.x / 2;
    final cy = size.y / 2;

    switch (type) {
      case PowerUpType.shield:
        // Shield shape
        final path = Path()
          ..moveTo(cx, cy - 10)
          ..lineTo(cx + 8, cy - 6)
          ..lineTo(cx + 8, cy + 2)
          ..lineTo(cx, cy + 10)
          ..lineTo(cx - 8, cy + 2)
          ..lineTo(cx - 8, cy - 6)
          ..close();
        canvas.drawPath(path, paint);
      case PowerUpType.magnet:
        final strokePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, cy), width: 16, height: 16),
          math.pi,
          math.pi,
          false,
          strokePaint,
        );
        canvas.drawRect(Rect.fromLTWH(cx - 8, cy - 2, 4, 8), paint);
        canvas.drawRect(Rect.fromLTWH(cx + 4, cy - 2, 4, 8), paint);
      case PowerUpType.ghost:
        // Friendly ghost — rounded dome with wavy hem and eyes.
        final body = Path()
          ..moveTo(cx - 8, cy + 1)
          ..lineTo(cx - 8, cy - 3)
          ..cubicTo(cx - 8, cy - 13, cx + 8, cy - 13, cx + 8, cy - 3)
          ..lineTo(cx + 8, cy + 1)
          ..lineTo(cx + 5, cy - 1)
          ..lineTo(cx + 2, cy + 1)
          ..lineTo(cx - 1, cy - 1)
          ..lineTo(cx - 4, cy + 1)
          ..lineTo(cx - 7, cy - 1)
          ..lineTo(cx - 8, cy + 1)
          ..close();
        canvas.drawPath(body, paint);
        // Eyes
        final eyePaint = Paint()
          ..color = const Color(0xFF00363A)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx - 3.5, cy - 3), 1.3, eyePaint);
        canvas.drawCircle(Offset(cx + 3.5, cy - 3), 1.3, eyePaint);
      case PowerUpType.slowMo:
        // Clock / hourglass
        final circlePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(Offset(cx, cy), 8, circlePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx + 5, cy - 4), circlePaint);
        canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy - 5), paint);
      case PowerUpType.coinRush:
        // Gold coin with a "+" spark — a burst of wealth.
        canvas.drawCircle(Offset(cx, cy), 8, paint);
        final innerPaint = Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), 5.5, innerPaint);
        final plusPaint = Paint()
          ..color = color
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - 2.5, cy), Offset(cx + 2.5, cy), plusPaint);
        canvas.drawLine(Offset(cx, cy - 2.5), Offset(cx, cy + 2.5), plusPaint);
    }
  }

  static Color _bgColorForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return const Color(0xFF1565C0); // blue
      case PowerUpType.magnet:
        return const Color(0xFF6A1B9A); // purple
      case PowerUpType.ghost:
        return const Color(0xFF00838F); // deep cyan
      case PowerUpType.slowMo:
        return const Color(0xFF00695C); // teal
      case PowerUpType.coinRush:
        return const Color(0xFFC77800); // amber gold
    }
  }

  static Color _iconColorForType(PowerUpType type) {
    return const Color(0xFFF7F9FC);
  }
}
