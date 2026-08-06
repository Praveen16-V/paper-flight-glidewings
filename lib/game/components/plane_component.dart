import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' show Colors;

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';

/// The player's paper plane.
///
/// Physics summary:
///   Y-axis (vertical on screen):
///     Hold → apply lift force upward (subtract from Y each frame).
///     Release → gravity pulls downward (add to Y each frame).
///     Fall off bottom edge → crash.
///
///   X-axis (horizontal):
///     inputManager.horizontalInput × maxTiltSpeed → target X velocity.
///     Modulated by wind lane lateral force.
///     Clamped to [edgeMargin, width - edgeMargin].
///
///   Rotation:
///     Visual tilt tracks vertical velocity — nose up when climbing,
///     nose down when diving. Horizontal tilt mirrors X velocity.
class PlaneComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  PlaneComponent({
    required this.game,
    required this.planeType,
  }) : super(
          size: Vector2(48, 32),
          anchor: Anchor.center,
        );

  final PaperFlightGame game;
  PlaneType planeType;

  // ── Physics State ─────────────────────────────────────────────────────────

  double _velocityY = 0.0; // px/s, positive = downward
  double _velocityX = 0.0; // px/s, positive = rightward

  // ── Visual State ──────────────────────────────────────────────────────────

  bool _isAlive = true;
  double _bankAngle = 0.0;    // visual roll for X movement
  double _pitchAngle = 0.0;   // visual pitch for Y movement

  // ── Sprite (placeholder rectangle until real assets load) ─────────────────
  // In a real build, use SpriteAnimationComponent loaded from assets.
  // For MVP scaffold, we render a coloured rectangle as a stand-in.
  late final RectangleComponent _body;
  late final RectangleComponent _wing;

  // ── Hitbox ────────────────────────────────────────────────────────────────

  late final RectangleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
    // Position plane at start position.
    position = Vector2(
      GameConfig.designWidth * GameConfig.planeStartX,
      GameConfig.designHeight * GameConfig.planeStartY,
    );

    // Hitbox — scaled smaller than sprite for forgiving collisions.
    final hbSize = size * GameConfig.planeHitboxScale;
    _hitbox = RectangleHitbox(
      size: hbSize,
      position: (size - hbSize) / 2,
    );
    add(_hitbox);

    await super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    // Paper-plane silhouette drawn with primitives (asset placeholder).
    final paint = Paint()
      ..color = const Color(0xFFF5A623) // accent gold
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;

    // Shadow offset
    canvas.save();
    canvas.translate(2, 3);
    _drawPlaneShape(canvas, shadowPaint, w, h);
    canvas.restore();

    _drawPlaneShape(canvas, paint, w, h);
    super.render(canvas);
  }

  void _drawPlaneShape(Canvas canvas, Paint paint, double w, double h) {
    // Simple dart silhouette path (nose right, tail left in local space).
    final path = Path()
      ..moveTo(w, h / 2)      // nose tip
      ..lineTo(0, 0)           // top wing tip
      ..lineTo(w * 0.3, h / 2) // body indent
      ..lineTo(0, h)           // bottom wing tip
      ..close();
    canvas.drawPath(path, paint);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_isAlive) return;
    if (game.phase != GamePhase.playing) return;

    final input = game.inputManager;
    final wind = game.windSystem;
    // Read sensitivity from inputManager (cached from settings, avoids per-frame provider read).
    final sensitivity = game.inputManager.currentSensitivity;

    // ── Vertical ────────────────────────────────────────────────────────────
    final fallMult = planeType.fallSpeedMultiplier;

    if (input.isHolding) {
      // Lift: accelerate upward (decrement Y velocity toward negative).
      _velocityY -= GameConfig.liftForce * dt;
    } else {
      // Gravity: accelerate downward.
      _velocityY += GameConfig.gravity * fallMult * dt;
    }

    // Paper-snap burst: strong upward kick.
    if (input.consumeSnap()) {
      _velocityY -= GameConfig.liftForce * 2.5;
    }

    _velocityY = _velocityY.clamp(
      -GameConfig.liftForce * 1.2,
      GameConfig.maxFallSpeed * fallMult,
    );

    // ── Horizontal ───────────────────────────────────────────────────────────
    final normX = position.x / GameConfig.designWidth;
    final laneIndex = wind.laneForNormX(normX);
    final laneWind = wind.windAt(laneIndex);

    // Turbulence reduces horizontal control.
    final controlMult = wind.isInTurbulence(normX)
        ? (1.0 - GameConfig.turbulenceControlReduction)
        : 1.0;

    final turnMult = planeType.turnSpeedMultiplier;
    final targetVX = input.horizontalInput *
        GameConfig.maxTiltSpeed *
        turnMult *
        controlMult *
        sensitivity;

    // Apply wind lateral push.
    final windContrib = laneWind.lateralForce;

    // Thermal lift bonus.
    if (laneWind.type == WindType.thermal) {
      _velocityY -= laneWind.liftBonus * dt;
    }

    _velocityX = MathUtils.lerp(_velocityX, targetVX + windContrib, 0.18);

    // ── Integrate Position ───────────────────────────────────────────────────
    position.x += _velocityX * dt;
    position.y += _velocityY * dt;

    // Clamp horizontal to screen bounds.
    position.x = position.x.clamp(
      GameConfig.horizontalEdgeMargin,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin,
    );

    // ── Fail State: fell off bottom ───────────────────────────────────────────
    if (position.y > GameConfig.designHeight + size.y) {
      game.onPlaneCrash();
      return;
    }

    // ── Visual Rotation ───────────────────────────────────────────────────────
    _pitchAngle = MathUtils.lerp(
      _pitchAngle,
      MathUtils.remap(_velocityY, -GameConfig.liftForce, GameConfig.maxFallSpeed, -0.35, 0.45),
      0.12,
    );
    _bankAngle = MathUtils.lerp(
      _bankAngle,
      MathUtils.remap(_velocityX, -GameConfig.maxTiltSpeed, GameConfig.maxTiltSpeed, -0.2, 0.2),
      0.10,
    );

    angle = _pitchAngle + _bankAngle;
  }

  // ── Collision ─────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    // Obstacle hits are handled by ObstacleComponent calling game.onPlaneCrash()
    // directly, so we only need to handle power-up / coin collisions here.
    // Those components check the collision themselves via onCollisionStart.
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void reset() {
    _isAlive = true;
    _velocityX = 0;
    _velocityY = 0;
    _pitchAngle = 0;
    _bankAngle = 0;
    angle = 0;
    position = Vector2(
      GameConfig.designWidth * GameConfig.planeStartX,
      GameConfig.designHeight * GameConfig.planeStartY,
    );

    // Remove any lingering effects.
    children.whereType<Effect>().toList().forEach(remove);
  }

  void revive() {
    _isAlive = true;
    _velocityY = 0;
    _velocityX = 0;
    position.y = GameConfig.designHeight * 0.5;
    // Brief invincibility flash.
    add(
      OpacityEffect.fadeOut(
        EffectController(
          duration: 0.1,
          reverseDuration: 0.1,
          repeatCount: 5,
        ),
      ),
    );
  }

  void playShieldHitAnimation() {
    // Quick scale bounce to signal a blocked hit.
    add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 0.08, reverseDuration: 0.08),
      ),
    );
  }

  Vector2 get worldPosition => absolutePosition;
}
