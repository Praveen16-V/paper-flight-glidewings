import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
import '../../../providers/game_session_provider.dart';
import '../../paper_flight_game.dart';
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
  void Function(PowerUpComponent)? onRecycle;
  double _bobPhase = 0;
  double _glowPulse = 0;

  void activate({
    required Vector2 spawnPosition,
    void Function(PowerUpComponent)? recycleCallback,
  }) {
    position = spawnPosition;
    _bobPhase = MathUtils.randomRange(0, math.pi * 2);
    _glowPulse = 0;
    _active = true;
    _collected = false;
    onRecycle = recycleCallback;
    // Reset visibility by removing any pending opacity effects.
    children.whereType<OpacityEffect>().toList().forEach(remove);

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size * 0.85, position: size * 0.075));
  }

  void deactivate() {
    _active = false;
    _collected = false;
    onRecycle = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void update(double dt) {
    if (!_active || _collected) return;

    position.y += gameRef.scrollSpeed * dt;
    _bobPhase += dt * 2.5;
    _glowPulse += dt * 4.0;

    // Subtle hover
    position.y += math.sin(_bobPhase) * 0.35;

    if (position.y > GameConfig.powerUpRecycleY) {
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
      _collect();
    }
  }

  void _collect() {
    _collected = true;
    _active = false;

    _applyEffect();

    add(ScaleEffect.by(
      Vector2.all(1.6),
      EffectController(duration: 0.1, reverseDuration: 0.08),
    ));
    add(OpacityEffect.fadeOut(
      EffectController(duration: 0.2),
      onComplete: () => onRecycle?.call(this),
    ));
  }

  void _applyEffect() {
    final notifier = gameRef.ref.read(gameSessionProvider.notifier);

    switch (type) {
      case PowerUpType.shield:
        notifier.activatePowerUp(PowerUpType.shield);
      case PowerUpType.magnet:
        notifier.activatePowerUp(PowerUpType.magnet);
        Future.delayed(
          Duration(milliseconds: (GameConfig.magnetDuration * 1000).toInt()),
          () => notifier.deactivatePowerUp(PowerUpType.magnet),
        );
      case PowerUpType.turboGust:
        notifier.activatePowerUp(PowerUpType.turboGust);
        Future.delayed(
          Duration(milliseconds: (GameConfig.turboDuration * 1000).toInt()),
          () => notifier.deactivatePowerUp(PowerUpType.turboGust),
        );
      case PowerUpType.slowMo:
        notifier.activatePowerUp(PowerUpType.slowMo);
        gameRef.applySlowMo(GameConfig.slowMoDuration);
      case PowerUpType.secondWind:
        // Second Wind: instant revive-like effect — restores to mid-screen.
        gameRef.plane.revive();
        notifier.activatePowerUp(PowerUpType.secondWind);
        Future.delayed(const Duration(milliseconds: 200),
            () => notifier.deactivatePowerUp(PowerUpType.secondWind));
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
      case PowerUpType.turboGust:
        // Lightning bolt
        final path = Path()
          ..moveTo(cx + 3, cy - 10)
          ..lineTo(cx - 2, cy - 1)
          ..lineTo(cx + 2, cy - 1)
          ..lineTo(cx - 3, cy + 10)
          ..lineTo(cx + 4, cy + 1)
          ..lineTo(cx - 1, cy + 1)
          ..close();
        canvas.drawPath(path, paint);
      case PowerUpType.slowMo:
        // Clock / hourglass
        final circlePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(Offset(cx, cy), 8, circlePaint);
        canvas.drawLine(Offset(cx, cy), Offset(cx + 5, cy - 4), circlePaint);
        canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy - 5), paint);
      case PowerUpType.secondWind:
        // Wind swirl
        final swirls = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        for (int i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(cx, cy - 4 + i * 4.0),
              width: 14 - i * 2,
              height: 6,
            ),
            0,
            math.pi,
            false,
            swirls,
          );
        }
    }
  }

  static Color _bgColorForType(PowerUpType type) {
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

  static Color _iconColorForType(PowerUpType type) {
    return const Color(0xFFF7F9FC);
  }
}
