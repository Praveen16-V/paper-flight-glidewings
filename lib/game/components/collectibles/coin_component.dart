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
class CoinComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks, HasPaint {
  CoinComponent()
      : super(
          size: Vector2.all(GameConfig.coinSize),
          anchor: Anchor.center,
        );

  bool _active = false;
  bool _collected = false;
  void Function(CoinComponent)? onRecycle;

  double _bobPhase = 0;
  double _spin = 0;

  bool get isActive => _active;

  void activate({
    required Vector2 spawnPosition,
    void Function(CoinComponent)? recycleCallback,
  }) {
    position = spawnPosition.clone();
    _bobPhase = MathUtils.randomRange(0, math.pi * 2);
    _spin = 0;
    _active = true;
    _collected = false;
    onRecycle = recycleCallback;
    opacity = 1.0;
    scale = Vector2.all(1.0);

    children.whereType<Effect>().toList().forEach(remove);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(
      radius: GameConfig.coinSize / 2 + 4,
      position: size / 2,
      anchor: Anchor.center,
    ));
  }

  void deactivate() {
    _active = false;
    _collected = false;
    onRecycle = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
    children.whereType<Effect>().toList().forEach(remove);
  }

  @override
  void update(double dt) {
    if (!_active || _collected) return;

    // Scroll down with world.
    position.y += game.effectiveScrollSpeed * dt;

    // Gentle bobbing + spin.
    _bobPhase += dt * 3.0;
    _spin += dt * 4.0;
    position.y += math.sin(_bobPhase) * 0.4;

    // Magnet pull — if magnet power-up active, accelerate toward plane.
    final session = game.ref.read(gameSessionProvider);
    if (session.activePowerUps.contains(PowerUpType.magnet)) {
      final plane = game.plane;
      final dist = MathUtils.distance(
        position.x,
        position.y,
        plane.position.x,
        plane.position.y,
      );
      if (dist < GameConfig.coinMagnetRadius) {
        final dir = (plane.position - position);
        final len = dir.length;
        if (len > 0.001) {
          position += dir.normalized() * (320 * dt);
        }
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
    game.scoringSystem.onCoinCollected();

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
    final r = size.x / 2;
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Squash X slightly with spin for coin-flip feel.
    final squash = 0.55 + 0.45 * math.cos(_spin).abs();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(squash, 1.0);

    final outerPaint = Paint()..color = const Color(0xFFFFD700);
    final innerPaint = Paint()..color = const Color(0xFFFFC107);
    final highlightPaint = Paint()..color = const Color(0xFFFFFF8D);

    canvas.drawCircle(Offset.zero, r, outerPaint);
    canvas.drawCircle(Offset.zero, r * 0.7, innerPaint);
    canvas.drawCircle(Offset(-r * 0.3, -r * 0.3), r * 0.15, highlightPaint);

    canvas.restore();
  }
}
