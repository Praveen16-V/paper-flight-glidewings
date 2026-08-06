import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';

/// The player's paper plane.
///
/// Physics summary (GDD §3):
///   Y-axis (vertical on screen):
///     Hold → apply lift force upward (subtract from Y each frame).
///     Release → gravity pulls downward (add to Y each frame).
///     Fall off bottom edge → crash.
///     No hard ceiling death — over-climbing punished by hazard proximity.
///
///   X-axis (horizontal):
///     inputManager.horizontalInput × maxTiltSpeed → target X velocity.
///     Modulated by wind lane lateral force + plane turn multiplier.
///     Momentum-based: diving (high |vY|) = sharper turns.
///
///   Rotation:
///     Visual tilt tracks vertical velocity — nose up when climbing,
///     nose down when diving. Horizontal bank mirrors X velocity.
class PlaneComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks, HasPaint {
  PlaneComponent({
    required this.game,
    required this.planeType,
  }) : super(
          size: Vector2(48, 32),
          anchor: Anchor.center,
          priority: 100,
        );

  final PaperFlightGame game;
  PlaneType planeType;

  // ── Physics State ─────────────────────────────────────────────────────────

  double _velocityY = 0.0; // px/s, positive = downward
  double _velocityX = 0.0; // px/s, positive = rightward

  // ── Visual State ──────────────────────────────────────────────────────────

  bool _isAlive = true;
  bool _invulnerable = false;
  double _bankAngle = 0.0;
  double _pitchAngle = 0.0;

  /// Wing-fold amount [0 = fully spread (gliding), 1 = folded up (holding)].
  double _wingFold = 0.0;

  // ── Hitbox ────────────────────────────────────────────────────────────────

  late final RectangleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
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
    final bodyColor = _colorForPlane(planeType);
    final paint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;

    // Rotate canvas so nose (local +X) points up (screen -Y).
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-pi / 2);
    canvas.translate(-w / 2, -h / 2);

    // Shadow
    canvas.save();
    canvas.translate(1.5, 2.5);
    _drawPlaneShape(canvas, shadowPaint, w, h, _wingFold);
    canvas.restore();

    _drawPlaneShape(canvas, paint, w, h, _wingFold);

    // Crease line
    final creasePaint = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.3, h / 2),
      Offset(w, h / 2),
      creasePaint,
    );

    canvas.restore();
    super.render(canvas);
  }

  /// Draws the paper-plane dart shape.
  /// Local-space: nose tip at (w, h/2), tail at left edge.
  void _drawPlaneShape(
      Canvas canvas, Paint paint, double w, double h, double wingFold) {
    final spreadY = h * 0.08;
    final topWingY =
        (h * 0.15) * (1.0 - wingFold) - spreadY * (1.0 - wingFold);
    final botWingY =
        h - (h * 0.15) * (1.0 - wingFold) + spreadY * (1.0 - wingFold);

    final bodyPath = Path()
      ..moveTo(w, h / 2)
      ..lineTo(w * 0.3, h / 2)
      ..lineTo(0, h / 2)
      ..close();

    final upperWing = Path()
      ..moveTo(w, h / 2)
      ..lineTo(w * 0.3, h / 2)
      ..lineTo(0, topWingY)
      ..close();

    final lowerWing = Path()
      ..moveTo(w, h / 2)
      ..lineTo(w * 0.3, h / 2)
      ..lineTo(0, botWingY)
      ..close();

    canvas.drawPath(upperWing, paint);
    canvas.drawPath(lowerWing, paint);
    canvas.drawPath(bodyPath, paint);
  }

  Color _colorForPlane(PlaneType type) {
    switch (type) {
      case PlaneType.dart:
        return const Color(0xFFF5A623);
      case PlaneType.glider:
        return const Color(0xFF4FC3F7);
      case PlaneType.stuntFold:
        return const Color(0xFFFF6B6B);
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_isAlive) return;
    if (game.phase != GamePhase.playing) return;

    final input = game.inputManager;
    final wind = game.windSystem;
    final sensitivity = input.currentSensitivity;

    // ── Vertical ────────────────────────────────────────────────────────────
    final fallMult = planeType.fallSpeedMultiplier;

    if (input.isHolding) {
      // Lift: accelerate upward (decrement Y velocity toward negative).
      _velocityY -= GameConfig.liftForce * dt;
    } else {
      // Gravity: accelerate downward.
      _velocityY += GameConfig.gravity * fallMult * dt;
    }

    // Paper-snap burst: strong upward kick (GDD §2 optional double-tap).
    if (input.consumeSnap()) {
      _velocityY -= GameConfig.liftForce * 2.5;
    }

    // Thermal lift bonus from wind system.
    final normX = position.x / GameConfig.designWidth;
    final laneIndex = wind.laneForNormX(normX);
    final laneWind = wind.windAt(laneIndex);

    if (laneWind.type == WindType.thermal) {
      _velocityY -= laneWind.liftBonus * dt;
    }

    _velocityY = _velocityY.clamp(
      -GameConfig.liftForce * 1.2,
      GameConfig.maxFallSpeed * fallMult,
    );

    // Soft ceiling — gently push back if above top margin (not a death).
    if (position.y < size.y * 0.5) {
      _velocityY = max(_velocityY, 40.0);
    }

    // ── Horizontal (momentum-based turning — GDD §3) ────────────────────────
    // Diving fast = sharper horizontal moves; climbing slow = gentle drift.
    final speedRatio = (_velocityY / GameConfig.maxFallSpeed).clamp(-1.0, 1.0);
    // When diving (positive vY) boost turn; when climbing reduce it.
    final momentumTurnBoost = 0.7 + 0.5 * ((speedRatio + 1.0) / 2.0);

    final controlMult = wind.isInTurbulence(normX)
        ? (1.0 - GameConfig.turbulenceControlReduction)
        : 1.0;

    final turnMult = planeType.turnSpeedMultiplier;
    final targetVX = input.horizontalInput *
        GameConfig.maxTiltSpeed *
        turnMult *
        controlMult *
        sensitivity *
        momentumTurnBoost;

    // Apply wind lateral push.
    final windContrib = laneWind.lateralForce;

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
    _wingFold = MathUtils.lerp(
      _wingFold,
      input.isHolding ? 1.0 : 0.0,
      0.14,
    );

    _pitchAngle = MathUtils.lerp(
      _pitchAngle,
      MathUtils.remap(
        _velocityY,
        -GameConfig.liftForce,
        GameConfig.maxFallSpeed,
        -0.35,
        0.45,
      ),
      0.12,
    );
    _bankAngle = MathUtils.lerp(
      _bankAngle,
      MathUtils.remap(
        _velocityX,
        -GameConfig.maxTiltSpeed,
        GameConfig.maxTiltSpeed,
        -0.2,
        0.2,
      ),
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
    // Obstacle hits are handled by ObstacleComponent calling game.onPlaneCrash().
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void reset() {
    _isAlive = true;
    _invulnerable = false;
    _velocityX = 0;
    _velocityY = 0;
    _pitchAngle = 0;
    _bankAngle = 0;
    _wingFold = 0;
    angle = 0;
    opacity = 1.0;
    position = Vector2(
      GameConfig.designWidth * GameConfig.planeStartX,
      GameConfig.designHeight * GameConfig.planeStartY,
    );

    children.whereType<Effect>().toList().forEach(remove);
  }

  void revive() {
    _isAlive = true;
    _velocityY = 0;
    _velocityX = 0;
    _wingFold = 0;
    position.y = GameConfig.designHeight * 0.5;
    position.x = GameConfig.designWidth * 0.5;
    opacity = 1.0;

    // Brief invincibility flash.
    _invulnerable = true;
    children.whereType<Effect>().toList().forEach(remove);
    add(
      OpacityEffect.fadeOut(
        EffectController(
          duration: 0.12,
          reverseDuration: 0.12,
          repeatCount: 6,
        ),
        onComplete: () {
          opacity = 1.0;
          _invulnerable = false;
        },
      ),
    );
  }

  bool get isInvulnerable => _invulnerable;

  void playShieldHitAnimation() {
    add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 0.08, reverseDuration: 0.08),
      ),
    );
  }

  void playCrashAnimation() {
    _isAlive = false;
    // Crumple: scale down + spin.
    add(
      ScaleEffect.to(
        Vector2.all(0.4),
        EffectController(duration: 0.15),
      ),
    );
    add(
      RotateEffect.by(
        pi * 0.6,
        EffectController(duration: 0.15),
      ),
    );
  }

  Vector2 get worldPosition => absolutePosition;
}
