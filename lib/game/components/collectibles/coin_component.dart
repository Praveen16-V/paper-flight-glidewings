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

/// A single coin collectible. Pooled and recycled by [CollectibleSpawner].
class CoinComponent extends CircleComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  CoinComponent()
      : super(
          radius: GameConfig.coinSize / 2,
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFFFFD700),
        );

  bool _active = false;
  bool _collected = false;
  void Function(CoinComponent)? onRecycle;

  // Bobbing animation phase
  double _bobPhase = 0;
  double _baseY = 0;

  void activate({
    required Vector2 spawnPosition,
    void Function(CoinComponent)? recycleCallback,
  }) {
    position = spawnPosition;
    _baseY = spawnPosition.y;
    _bobPhase = MathUtils.randomRange(0, math.pi * 2);
    _active = true;
    _collected = false;
    onRecycle = recycleCallback;
    paint.color = const Color(0xFFFFD700); // restore full opacity

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: radius + 4)); // slightly larger for generosity
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

    // Scroll down with world.
    position.y += game.scrollSpeed * dt;

    // Gentle bobbing.
    _bobPhase += dt * 3.0;
    position.y += math.sin(_bobPhase) * 0.4;

    // Magnet pull — if magnet power-up active, accelerate toward plane.
    final session = gameRef.ref.read(gameSessionProvider);
    if (session.activePowerUps.contains(PowerUpType.magnet)) {
      final plane = gameRef.plane;
      final dist = MathUtils.distance(
        position.x, position.y,
        plane.position.x, plane.position.y,
      );
      if (dist < GameConfig.coinMagnetRadius) {
        final dir = (plane.position - position).normalized();
        position += dir * (300 * dt);
      }
    }

    // Recycle below viewport.
    if (position.y > GameConfig.coinRecycleY) {
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

    // Award score via scoring system.
    gameRef.scoringSystem.onCoinCollected();

    // Satisfying pop + float-up animation before recycle.
    add(ScaleEffect.by(
      Vector2.all(1.5),
      EffectController(duration: 0.08, reverseDuration: 0.06),
    ));
    add(OpacityEffect.fadeOut(
      EffectController(duration: 0.18),
      onComplete: () => onRecycle?.call(this),
    ));
  }

  @override
  void render(Canvas canvas) {
    // Gold coin with inner ring.
    final outerPaint = Paint()..color = const Color(0xFFFFD700);
    final innerPaint = Paint()..color = const Color(0xFFFFC107);
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFFF8D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, radius, outerPaint);
    canvas.drawCircle(Offset.zero, radius * 0.7, innerPaint);
    // Small highlight dot
    canvas.drawCircle(Offset(-radius * 0.3, -radius * 0.3), radius * 0.15,
        highlightPaint);
  }
}
