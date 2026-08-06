import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';
import 'plane_trail_component.dart';

/// The player's paper plane.
///
/// Physics model (three states):
///
///   HOLD (press edge)
///     → No instant kick: the current velocity eases toward liftCruiseSpeed
///       via lerp(t = liftKickDecayRate × dt), so touching down never jolts.
///     → Wing squish ScaleEffect plays on the press edge.
///
///   GLIDE ARC (release edge, while upward momentum remains)
///     → At release: preserve glideArcPreservation fraction of upward velocity.
///     → Lighter gravity (glideGravityScale) so the arc coasts naturally.
///     → Sinusoidal oscillation ramps up from zero.
///     → Nose-up pitch bias while still moving upward.
///     → Arc ends when velocityY crosses zero (plane tips into fall).
///
///   FALL (glide arc spent or releasing from a downward state)
///     → Full gravity (fullGravityScale × fallSpeedMultiplier).
///     → Oscillation continues at full strength.
///
///   X-axis / wind / thermal: unchanged from original design.
///
///   Rotation:
///     Adaptive lerp speed — faster response at high velocity changes.
///     Pitch maps vY → angle; bank maps vX → angle.
///     Glide-arc nose-up bias while coasting upward.
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

  // ── Physics State ──────────────────────────────────────────────────────────

  double _velocityY = 0.0; // px/s, positive = downward
  double _velocityX = 0.0; // px/s, positive = rightward

  // Hold-state tracking for edge detection.
  bool _wasHolding = false;

  // Glide arc state.
  bool _glideArcActive = false;

  // Oscillation state.
  double _oscillationPhase = 0.0;   // radians, ticks every frame
  double _oscillationStrength = 0.0; // [0,1], ramps up after release

  // ── Visual State ───────────────────────────────────────────────────────────

  bool _isAlive = true;
  double _bankAngle = 0.0;   // visual roll for X movement
  double _pitchAngle = 0.0;  // visual pitch for Y movement

  /// Wing-fold amount [0 = fully spread (gliding), 1 = folded up (holding)].
  double _wingFold = 0.0;

  // ── Children ───────────────────────────────────────────────────────────────

  late final PlaneTrailComponent _trail;
  late final RectangleHitbox _hitbox;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    position = Vector2(
      GameConfig.designWidth * GameConfig.planeStartX,
      GameConfig.designHeight * GameConfig.planeStartY,
    );

    // Trail renders behind the plane (added first → drawn first in Flame).
    _trail = PlaneTrailComponent(plane: this);
    add(_trail);

    // Hitbox — scaled smaller than sprite for forgiving collisions.
    final hbSize = size * GameConfig.planeHitboxScale;
    _hitbox = RectangleHitbox(
      size: hbSize,
      position: (size - hbSize) / 2,
    );
    add(_hitbox);

    await super.onLoad();
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFF5A623) // accent gold
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;

    // Rotate canvas so the nose (local +X) points up (screen -Y).
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-pi / 2);
    canvas.translate(-w / 2, -h / 2);

    // Shadow offset.
    canvas.save();
    canvas.translate(1.5, 2.5);
    _drawPlaneShape(canvas, shadowPaint, w, h, _wingFold);
    canvas.restore();

    _drawPlaneShape(canvas, paint, w, h, _wingFold);

    // Subtle crease line separating upper/lower wing faces.
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
  ///
  /// Local-space: nose tip at (w, h/2), tail at left edge.
  /// [wingFold] 0 = wings spread (gliding), 1 = wings folded (holding).
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

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_isAlive) return;
    if (game.phase != GamePhase.playing) return;

    final input = game.inputManager;
    final wind = game.windSystem;
    final sensitivity = game.inputManager.currentSensitivity;
    final fallMult = planeType.fallSpeedMultiplier;

    final isHolding = input.isHolding;
    final pressEdge = isHolding && !_wasHolding;   // first frame of hold
    final releaseEdge = !isHolding && _wasHolding; // first frame of release

    // ── Vertical Physics ─────────────────────────────────────────────────────

    if (pressEdge) {
      // Do not assign an upward velocity here. The hold target below is eased
      // toward from the current velocity, so touching down never jolts the plane.
      _glideArcActive = false;
      _oscillationStrength = 0.0;
      _playHoldKickEffect();
    }

    if (isHolding) {
      // Ease into a calm climb rather than applying a one-frame lift kick.
      _velocityY = MathUtils.lerp(
        _velocityY,
        GameConfig.liftCruiseSpeed,
        (GameConfig.liftKickDecayRate * dt).clamp(0.0, 1.0),
      );
      // Damp oscillation while holding — paper is under active lift.
      _oscillationStrength =
          (_oscillationStrength - 3.0 * dt).clamp(0.0, 1.0);
    } else {
      // Release path.
      if (releaseEdge) {
        if (_velocityY < 0) {
          // Keep the exact current momentum. Gravity takes over gradually,
          // which makes finger-up continuous instead of a velocity jump.
          _glideArcActive = true;
        } else {
          // Released while already falling — skip arc, go straight to fall.
          _glideArcActive = false;
        }
        _oscillationPhase = 0.0;
        _oscillationStrength = 0.0;
      }

      if (_glideArcActive) {
        // Lighter gravity during the upward coast.
        _velocityY +=
            GameConfig.gravity * GameConfig.glideGravityScale * fallMult * dt;

        // Ramp oscillation up from zero so it doesn't pop in jarringly.
        _oscillationStrength = (_oscillationStrength +
                GameConfig.oscillationFadeInRate * dt)
            .clamp(0.0, 1.0);

        // Arc ends when velocity tips downward — now in natural fall.
        if (_velocityY >= 0) {
          _glideArcActive = false;
        }
      } else {
        // Full gravity fall.
        _velocityY +=
            GameConfig.gravity * GameConfig.fullGravityScale * fallMult * dt;

        // Keep oscillation at full strength during free fall.
        _oscillationStrength =
            (_oscillationStrength + GameConfig.oscillationFadeInRate * dt)
                .clamp(0.0, 1.0);
      }

      // Sinusoidal oscillation — simulates the natural undulation of a paper
      // plane riding air. Added as a velocity contribution each frame.
      _oscillationPhase +=
          GameConfig.oscillationFrequency * 2.0 * pi * dt;
      final oscContrib = sin(_oscillationPhase) *
          GameConfig.oscillationAmplitude *
          _oscillationStrength;
      _velocityY += oscContrib * dt;
    }

    // Paper-snap burst: strong upward kick (double-tap power).
    if (input.consumeSnap()) {
      _velocityY = GameConfig.liftSnapKick * 1.8;
      _glideArcActive = false;
    }

    // Thermal lift bonus from wind lane.
    final normX = position.x / GameConfig.designWidth;
    final laneIndex = wind.laneForNormX(normX);
    final laneWind = wind.windAt(laneIndex);
    if (laneWind.type == WindType.thermal) {
      _velocityY -= laneWind.liftBonus * dt;
    }

    // Clamp velocity range.
    _velocityY = _velocityY.clamp(
      GameConfig.liftSnapKick * 1.8, // max upward speed matches snap burst
      GameConfig.maxFallSpeed * fallMult,
    );

    // ── Horizontal Physics ────────────────────────────────────────────────────

    final controlMult = wind.isInTurbulence(normX)
        ? (1.0 - GameConfig.turbulenceControlReduction)
        : 1.0;

    final turnMult = planeType.turnSpeedMultiplier;
    final targetVX = input.horizontalInput *
        GameConfig.maxTiltSpeed *
        turnMult *
        controlMult *
        sensitivity;

    _velocityX = MathUtils.lerp(
      _velocityX,
      targetVX + laneWind.lateralForce,
      GameConfig.tiltVelocityResponse,
    );

    // ── Integrate Position ────────────────────────────────────────────────────

    position.x += _velocityX * dt;
    position.y += _velocityY * dt;

    position.x = position.x.clamp(
      GameConfig.horizontalEdgeMargin,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin,
    );

    // ── Fail State ────────────────────────────────────────────────────────────

    if (position.y > GameConfig.designHeight + size.y) {
      game.onPlaneCrash();
      return;
    }

    // ── Visual Rotation (Task 3) ───────────────────────────────────────────────

    _updateRotation();

    // ── Wing Fold ─────────────────────────────────────────────────────────────

    // Ease the wing response as well, matching the softer hold/release motion.
    _wingFold = MathUtils.lerp(_wingFold, isHolding ? 1.0 : 0.0, 0.10);

    // ── Edge Tracking ─────────────────────────────────────────────────────────

    _wasHolding = isHolding;
  }

  // ── Rotation Update (Task 3) ──────────────────────────────────────────────

  void _updateRotation() {
    // Adaptive pitch lerp: responds faster when velocity is changing quickly.
    final pitchLerpT = MathUtils.remap(
      _velocityY.abs(),
      0,
      GameConfig.maxFallSpeed,
      0.06,
      0.18,
    );

    // Pitch target: nose-up when climbing, nose-down when falling.
    // Slightly wider range than original for more expressive feel.
    double pitchTarget = MathUtils.remap(
      _velocityY,
      GameConfig.liftCruiseSpeed, // full climb speed → max nose-up
      GameConfig.maxFallSpeed,    // max fall speed  → max nose-down
      -0.42,
      0.52,
    );

    // Glide arc nose-up bias: plane "floats" with nose slightly raised while
    // coasting upward — the most characteristic paper-plane moment.
    if (_glideArcActive && _velocityY < 0) {
      pitchTarget += GameConfig.glideNoseUpBias;
    }

    _pitchAngle = MathUtils.lerp(_pitchAngle, pitchTarget, pitchLerpT);

    // Adaptive bank lerp.
    final bankLerpT = MathUtils.remap(
      _velocityX.abs(),
      0,
      GameConfig.maxTiltSpeed,
      0.07,
      0.16,
    );

    final bankTarget = MathUtils.remap(
      _velocityX,
      -GameConfig.maxTiltSpeed,
      GameConfig.maxTiltSpeed,
      -0.22,
      0.22,
    );

    _bankAngle = MathUtils.lerp(_bankAngle, bankTarget, bankLerpT);

    angle = _pitchAngle + _bankAngle;
  }

  // ── Wing Squish Effect (Task 4) ────────────────────────────────────────────

  void _playHoldKickEffect() {
    // Remove any in-progress squish to prevent stacking.
    children.whereType<ScaleEffect>().toList().forEach(remove);

    // Brief wing-compression squish: slight X spread + Y compress, springs back.
    add(
      ScaleEffect.by(
        Vector2(1.06, GameConfig.wingSquishScaleY),
        EffectController(
          duration: GameConfig.wingSquishDuration / 2,
          reverseDuration: GameConfig.wingSquishDuration / 2,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
      ),
    );
  }

  // ── Collision ─────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    // Obstacle hits handled by ObstacleComponent → game.onPlaneCrash() directly.
    // Power-up / coin collisions handled by those components' onCollisionStart.
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void reset() {
    _isAlive = true;
    _velocityX = 0;
    _velocityY = 0;
    _pitchAngle = 0;
    _bankAngle = 0;
    _wingFold = 0;
    _wasHolding = false;
    _glideArcActive = false;
    _oscillationPhase = 0;
    _oscillationStrength = 0;
    angle = 0;
    position = Vector2(
      GameConfig.designWidth * GameConfig.planeStartX,
      GameConfig.designHeight * GameConfig.planeStartY,
    );

    _trail.clear();

    // Remove any lingering effects.
    children.whereType<Effect>().toList().forEach(remove);
  }

  void revive() {
    _isAlive = true;
    _velocityY = 0;
    _velocityX = 0;
    _wingFold = 0;
    _wasHolding = false;
    _glideArcActive = false;
    _oscillationPhase = 0;
    _oscillationStrength = 0;
    position.y = GameConfig.designHeight * 0.5;

    _trail.clear();

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
    add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 0.08, reverseDuration: 0.08),
      ),
    );
  }

  Vector2 get worldPosition => absolutePosition;
}
