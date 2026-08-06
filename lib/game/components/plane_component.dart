import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../providers/game_session_provider.dart';
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
    this.paperSkin = PaperSkin.plain,
  }) : super(
          size: Vector2(48, 32),
          anchor: Anchor.center,
        );

  final PaperFlightGame game;
  PlaneType planeType;
  PaperSkin paperSkin;

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

  // Ceiling stall state.
  double _ceilingStallTimer = 0.0; // seconds remaining in stall dip
  bool _ceilingWasInSoftZone = false;

  // ── Visual State ───────────────────────────────────────────────────────────

  bool _isAlive = true;
  double _bankAngle = 0.0;   // visual roll for X movement
  double _pitchAngle = 0.0;  // visual pitch for Y movement

  /// Wing-fold amount [0 = fully spread (gliding), 1 = folded up (holding)].
  double _wingFold = 0.0;

  // ── Active Power-up Visual State ─────────────────────────────────────────

  bool _shieldActive = false;
  bool _ghostActive = false;
  bool _magnetActive = false;
  bool _coinRushActive = false;

  /// Phase used to flicker the ghost-translucency outline.
  double _ghostFlickerPhase = 0;

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

    // Hitbox — per-plane override for Stealth Jet.
    final scale = planeType.hitboxScaleOverride ?? GameConfig.planeHitboxScale;
    final hbSize = size * scale;
    _hitbox = RectangleHitbox(
      size: hbSize,
      position: (size - hbSize) / 2,
    );
    add(_hitbox);

    await super.onLoad();
  }

  /// Update hitbox when plane type changes (hangar equip).
  void syncHitboxForPlaneType(PlaneType newType) {
    planeType = newType;
    final scale = newType.hitboxScaleOverride ?? GameConfig.planeHitboxScale;
    final hbSize = size * scale;
    _hitbox.size = hbSize;
    _hitbox.position = (size - hbSize) / 2;
  }

  /// Update skin at runtime (hangar equip).
  void syncSkin(PaperSkin newSkin) {
    paperSkin = newSkin;
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final baseColor = Color(paperSkin.baseColorHex);
    // Plain keeps classic gold; other skins tint the plane.
    final Color planeColor = paperSkin == PaperSkin.plain
        ? const Color(0xFFF5A623)
        : baseColor;
    final paint = Paint()
      ..color = planeColor
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;

    // Ghost: plane becomes translucent and shimmers while phasing.
    if (_ghostActive) {
      final flicker = 0.55 + 0.2 * sin(_ghostFlickerPhase);
      paint.color = paint.color.withOpacity(flicker.clamp(0.4, 0.9));
    }

    // Rotate canvas so the nose (local +X) points up (screen -Y).
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-pi / 2);
    canvas.translate(-w / 2, -h / 2);

    // Shadow offset.
    canvas.save();
    canvas.translate(1.5, 2.5);
    _drawPlaneShape(canvas, shadowPaint, w, h, _wingFold, isShadow: true);
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

    // Night Sky: a subtle forward cone makes hazards readable in the dark.
    if (game.biomeManager.currentBiome == Biome.night) {
      final lamp = Paint()
        ..shader = RadialGradient(colors: [const Color(0x55FFF6C4), const Color(0x00FFF6C4)]).createShader(Rect.fromCircle(center: Offset(w / 2, h / 2 - 55), radius: 82));
      canvas.drawCircle(Offset(w / 2, h / 2 - 55), 82, lamp);
    }

    // Paper-skin overlay patterns (subtle, drawn on top of plane but under effects)
    _drawSkinOverlay(canvas, w, h);

    // Power-up overlay visuals, drawn in screen space around the plane on top
    // of children (trail) so bubbles/auras read clearly.
    if (_ghostActive) _drawGhostShimmer(canvas, w, h);
    if (_magnetActive) _drawMagnetAura(canvas, w, h);
    if (_coinRushActive) _drawCoinRushGlow(canvas, w, h);
    if (_shieldActive) _drawShieldBubble(canvas, w, h);

    // Snap charge ring — always visible during playing phase.
    _drawSnapChargeRing(canvas, w, h);
  }

  void _drawSkinOverlay(Canvas canvas, double w, double h) {
    // Only draw for non-plain skins; plain already looks classic.
    if (paperSkin == PaperSkin.plain) return;
    final pulse = sin(_ghostFlickerPhase * 0.5) * 0.08 + 0.92;
    switch (paperSkin) {
      case PaperSkin.plain:
        break;
      case PaperSkin.newspaper:
        // Newspaper: faint horizontal lines + tiny text dots
        final linePaint = Paint()
          ..color = const Color(0xFF5D4037).withOpacity(0.18 * pulse)
          ..strokeWidth = 0.6;
        for (double y = h * 0.25; y < h * 0.85; y += 3.5) {
          canvas.drawLine(Offset(w * 0.2, y), Offset(w * 0.85, y), linePaint);
        }
        break;
      case PaperSkin.graphPaper:
        final gridPaint = Paint()
          ..color = const Color(0xFF0288D1).withOpacity(0.20)
          ..strokeWidth = 0.5;
        for (double x = w * 0.15; x < w; x += 7) {
          canvas.drawLine(Offset(x, h * 0.2), Offset(x, h * 0.8), gridPaint);
        }
        for (double y = h * 0.25; y < h * 0.85; y += 7) {
          canvas.drawLine(Offset(w * 0.15, y), Offset(w * 0.9, y), gridPaint);
        }
        break;
      case PaperSkin.notebookDoodle:
        final linePaint = Paint()
          ..color = const Color(0xFF4FC3F7).withOpacity(0.35)
          ..strokeWidth = 0.7;
        for (double y = h * 0.3; y < h * 0.8; y += 6) {
          canvas.drawLine(Offset(w * 0.18, y), Offset(w * 0.88, y), linePaint);
        }
        // Red margin
        final marginPaint = Paint()
          ..color = const Color(0xFFFF5252).withOpacity(0.5)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(w * 0.25, h * 0.18), Offset(w * 0.25, h * 0.82), marginPaint);
        // Tiny doodle star
        final doodlePaint = Paint()
          ..color = const Color(0xFF5D4037).withOpacity(0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9;
        canvas.drawCircle(Offset(w * 0.75, h * 0.35), 3.5 * pulse, doodlePaint);
        break;
      case PaperSkin.holographicFoil:
        final foilPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFE040FB).withOpacity(0.22),
              const Color(0xFF00E5FF).withOpacity(0.22),
              const Color(0xFF76FF03).withOpacity(0.22),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h))
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.92, height: h * 0.72),
            const Radius.circular(6),
          ),
          foilPaint,
        );
        break;
      case PaperSkin.watercolorWash:
        final washPaint = Paint()
          ..color = const Color(0xFF80DEEA).withOpacity(0.18 + 0.07 * sin(_ghostFlickerPhase * 0.4))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(w * 0.55, h * 0.45), 14 * pulse, washPaint);
        canvas.drawCircle(Offset(w * 0.4, h * 0.6), 9, washPaint);
        break;
      case PaperSkin.goldLeaf:
        final goldPaint = Paint()
          ..color = const Color(0xFFFFD700).withOpacity(0.28 * pulse)
          ..style = PaintingStyle.fill;
        // Small flecks
        canvas.drawCircle(Offset(w * 0.3, h * 0.4), 2.2, goldPaint);
        canvas.drawCircle(Offset(w * 0.65, h * 0.52), 1.8, goldPaint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.7), 1.4, goldPaint);
        // Rim glow
        final rim = Paint()
          ..color = const Color(0xFFFFD700).withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.96, height: h * 0.76),
            const Radius.circular(5),
          ),
          rim,
        );
        break;
    }
  }

  /// Shimmering cyan ghost outline + small drift wisps while phasing.
  void _drawGhostShimmer(Canvas canvas, double w, double h) {
    final pulse = 0.35 + 0.25 * sin(_ghostFlickerPhase);
    final paint = Paint()
      ..color = Color.fromRGBO(128, 222, 234, pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: w + 10,
          height: h + 10,
        ),
        const Radius.circular(8),
      ),
      paint,
    );
  }

  /// Purple aura ring radiating while the coin magnet is active.
  void _drawMagnetAura(Canvas canvas, double w, double h) {
    final pulse = 0.35 + 0.2 * sin(_ghostFlickerPhase * 0.8);
    final glowPaint = Paint()
      ..color = Color.fromRGBO(171, 71, 188, pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final ringPaint = Paint()
      ..color = Color.fromRGBO(212, 143, 229, 0.7 + 0.3 * sin(_ghostFlickerPhase))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final r = w * 0.75 + 4.0;
    canvas.drawCircle(Offset(w / 2, h / 2), r + 6, glowPaint);
    canvas.drawCircle(Offset(w / 2, h / 2), r, ringPaint);
  }

  /// Warm golden halo while Coin Rush is active.
  void _drawCoinRushGlow(Canvas canvas, double w, double h) {
    final pulse = 0.3 + 0.2 * sin(_ghostFlickerPhase * 0.7);
    final glowPaint = Paint()
      ..color = Color.fromRGBO(255, 200, 60, pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final r = w * 0.8;
    canvas.drawCircle(Offset(w / 2, h / 2), r + 4, glowPaint);
  }

  /// Charge ring around the plane showing 2 snap charges and recharge progress.
  void _drawSnapChargeRing(Canvas canvas, double w, double h) {
    // Only show during active run; faint when full, pulsing when recharging.
    if (game.phase != GamePhase.playing && game.phase != GamePhase.paused) return;

    final input = game.inputManager;
    final charges = input.snapCharges;
    final progress = input.snapRechargeFraction; // 0..1 for next charge
    final center = Offset(w / 2, h / 2);
    final radius = GameConfig.snapRingRadius;
    final stroke = GameConfig.snapRingStrokeWidth;

    // Background faint circle
    final bgPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    const gap = GameConfig.snapRingGapRadians;
    final totalArc = (2 * pi - gap * GameConfig.snapMaxCharges) / GameConfig.snapMaxCharges;

    for (int i = 0; i < GameConfig.snapMaxCharges; i++) {
      final start = -pi / 2 + i * (totalArc + gap);
      double sweep = totalArc;
      bool isFilled = i < charges;
      double fillFraction = 1.0;
      Paint segPaint;

      if (isFilled) {
        // Available charge — solid accent.
        segPaint = Paint()
          ..color = const Color(0xFFF5A623).withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
      } else if (i == charges && charges < GameConfig.snapMaxCharges) {
        // Next charge is recharging — draw partial arc based on progress.
        fillFraction = progress.clamp(0.0, 1.0);
        if (fillFraction <= 0.01) continue;
        sweep = totalArc * fillFraction;
        final pulse = 0.45 + 0.25 * sin(_ghostFlickerPhase * 0.9);
        segPaint = Paint()
          ..color = const Color(0xFFF5A623).withOpacity(pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
      } else {
        // Locked charge — dim.
        segPaint = Paint()
          ..color = const Color(0x33FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.85
          ..strokeCap = StrokeCap.round;
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        segPaint,
      );
    }

    // Flash the ring briefly when a snap was just used — scale via phase.
    if (_snapFlashTimer > 0) {
      final f = (_snapFlashTimer / 0.2).clamp(0.0, 1.0);
      final flashPaint = Paint()
        ..color = const Color(0xFFF5A623).withOpacity(0.5 * f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 2.5 * f
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, radius + 2, flashPaint);
    }
  }

  double _snapFlashTimer = 0.0;

  /// True while the plane's wind lane is a thermal updraft — read by the
  /// thermal-surf streak tracker.
  bool _inThermal = false;
  bool get isInThermal => _inThermal;

  void _triggerSnapFlash() {
    _snapFlashTimer = 0.22;
  }

  /// Pulsing blue shield bubble protecting the plane from one hit.
  void _drawShieldBubble(Canvas canvas, double w, double h) {
    final pulse = 0.5 + 0.3 * sin(_ghostFlickerPhase * 1.2);
    final bubblePaint = Paint()
      ..color = Color.fromRGBO(100, 181, 246, 0.18 + 0.12 * pulse)
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = Color.fromRGBO(144, 202, 249, 0.8 + 0.2 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final r = (w > h ? w : h) * 0.72;
    canvas.drawCircle(Offset(w / 2, h / 2), r, bubblePaint);
    canvas.drawCircle(Offset(w / 2, h / 2), r, rimPaint);
    // Glossy highlight
    final glossPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2 - r * 0.3, h / 2 - r * 0.35), r * 0.18, glossPaint);
  }

  /// Draws the paper-plane dart shape.
  ///
  /// Local-space: nose tip at (w, h/2), tail at left edge.
  /// [wingFold] 0 = wings spread (gliding), 1 = wings folded (holding).
  void _drawPlaneShape(
      Canvas canvas, Paint paint, double w, double h, double wingFold,
      {bool isShadow = false}) {
    final spreadY = h * 0.08;
    final topWingY =
        (h * 0.15) * (1.0 - wingFold) - spreadY * (1.0 - wingFold);
    final botWingY =
        h - (h * 0.15) * (1.0 - wingFold) + spreadY * (1.0 - wingFold);

    // Plane-variant silhouette tweaks
    double noseExtra = 0;
    double wingSweep = 0;
    if (planeType == PlaneType.glider) {
      // Glider: slightly longer, broader wings
      noseExtra = w * 0.06;
      wingSweep = h * 0.06;
    } else if (planeType == PlaneType.stealthJet) {
      // Stealth: sharper, more swept delta
      noseExtra = w * 0.08;
      wingSweep = -h * 0.04;
    } else if (planeType == PlaneType.crane) {
      // Crane: softer, more folded crane-like
      noseExtra = -w * 0.04;
    }

    final bodyPath = Path()
      ..moveTo(w + noseExtra, h / 2)
      ..lineTo(w * 0.3, h / 2)
      ..lineTo(0, h / 2)
      ..close();

    final upperWing = Path()
      ..moveTo(w + noseExtra, h / 2)
      ..lineTo(w * 0.3, h / 2)
      ..lineTo(0, topWingY - wingSweep)
      ..close();

    final lowerWing = Path()
      ..moveTo(w + noseExtra, h / 2)
      ..lineTo(w * 0.3, h / 2)
      ..lineTo(0, botWingY + wingSweep)
      ..close();

    canvas.drawPath(upperWing, paint);
    canvas.drawPath(lowerWing, paint);
    canvas.drawPath(bodyPath, paint);

    // Gold leaf / holographic pick up a little highlight only when not shadow
    if (!isShadow && (paperSkin == PaperSkin.goldLeaf || paperSkin == PaperSkin.holographicFoil)) {
      final hl = Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      canvas.drawPath(upperWing, hl);
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_isAlive) return;
    if (game.phase != GamePhase.playing) return;

    final input = game.inputManager;
    final wind = game.windSystem;
    final sensitivity = game.inputManager.currentSensitivity;
    // Apply per-plane fall multiplier
    final fallMult = planeType.fallSpeedMultiplier;

    final isHolding = input.isHolding;
    final pressEdge = isHolding && !_wasHolding;   // first frame of hold
    final releaseEdge = !isHolding && _wasHolding; // first frame of release

    // Reflect active power-ups so render() can draw their visuals.
    final session = gameRef.ref.read(gameSessionProvider);
    _shieldActive = session.shieldActive;
    _ghostActive = session.activePowerUps.contains(PowerUpType.ghost);
    _magnetActive = session.activePowerUps.contains(PowerUpType.magnet);
    _coinRushActive = session.activePowerUps.contains(PowerUpType.coinRush);
    if (_ghostActive) _ghostFlickerPhase += dt * 20.0;
    // Tick visual timers.
    if (_ghostActive || _magnetActive || _coinRushActive) {
      if (!_ghostActive) _ghostFlickerPhase += dt * 8.0;
    } else {
      _ghostFlickerPhase += dt * 6.0; // still tick for snap ring pulse
    }
    if (_snapFlashTimer > 0) _snapFlashTimer = (_snapFlashTimer - dt).clamp(0.0, 10.0);
    if (_ceilingStallTimer > 0) _ceilingStallTimer = (_ceilingStallTimer - dt).clamp(0.0, 10.0);

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

      // Glider gets a wider, floatier arc via lighter glide gravity
      final glideScale = planeType == PlaneType.glider
          ? GameConfig.glideGravityScale * GameConfig.gliderGlideGravityFactor
          : GameConfig.glideGravityScale;
      // Stealth dive recovery: less gravity when falling fast
      final diveRecoveryScale = (planeType == PlaneType.stealthJet && _velocityY > 60)
          ? GameConfig.stealthDiveRecoveryGravityScale
          : 1.0;

      if (_glideArcActive) {
        // Lighter gravity during the upward coast.
        _velocityY +=
            GameConfig.gravity * glideScale * fallMult * wind.profile.gravity * diveRecoveryScale * dt;

        // Ramp oscillation up from zero so it doesn't pop in jarringly.
        _oscillationStrength = (_oscillationStrength +
                GameConfig.oscillationFadeInRate * dt)
            .clamp(0.0, 1.0);

        // Arc ends when velocity tips downward — now in natural fall.
        if (_velocityY >= 0) {
          _glideArcActive = false;
        }
      } else {
        // Full gravity fall — stealth recovers faster.
        final fullScale = GameConfig.fullGravityScale * diveRecoveryScale;
        _velocityY +=
            GameConfig.gravity * fullScale * fallMult * wind.profile.gravity * dt;

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

    // Paper-snap burst: strong upward kick (double-tap / flick / button).
    if (input.consumeSnap()) {
      _velocityY = GameConfig.snapBurstVelocity;
      _glideArcActive = false;
      _triggerSnapFlash();
      _playSnapBurstEffect();
    }

    // Thermal lift bonus from wind lane — glider gets +20% float.
    final normX = position.x / GameConfig.designWidth;
    final laneIndex = wind.laneForNormX(normX);
    final laneWind = wind.windAt(laneIndex);
    final inThermal = laneWind.type == WindType.thermal;
    _inThermal = inThermal;
    if (inThermal) {
      double lift = laneWind.liftBonus;
      if (planeType == PlaneType.glider) {
        lift *= GameConfig.gliderThermalBonusMultiplier;
      }
      _velocityY -= lift * dt;
    }

    // Clamp velocity range.
    _velocityY = _velocityY.clamp(
      GameConfig.snapBurstVelocity, // max upward speed matches snap burst
      GameConfig.maxFallSpeed * fallMult,
    );

    // ── Horizontal Physics ────────────────────────────────────────────────────

    final controlMult = wind.isInTurbulence(normX)
        ? (1.0 - GameConfig.turbulenceControlReduction)
        : 1.0;
    double biomeControl = wind.profile.control;
    // Stealth handles wind better
    if (planeType == PlaneType.stealthJet) {
      biomeControl *= GameConfig.stealthWindControlBonus;
    }

    final turnMult = planeType.turnSpeedMultiplier;
    final baseSpeed = input.currentScheme == ControlScheme.joystick
        ? GameConfig.joystickMaxSteerSpeed
        : GameConfig.maxTiltSpeed;
    final targetVX = input.horizontalInput *
        baseSpeed *
        turnMult *
        controlMult *
        biomeControl *
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

    // ── Soft Altitude Ceiling (aerodynamic resistance + stall) ───────────────
    _handleCeiling(dt);

    // ── Fail State ────────────────────────────────────────────────────────────

    if (position.y > GameConfig.designHeight + size.y) {
      game.onPlaneCrash();
      return;
    }

    // ── Visual Rotation (Task 3) ───────────────────────────────────────────────

    _updateRotation();
    // Turbulence visibly rattles the wings as well as reducing control.
    if (wind.isInTurbulence(normX)) {
      angle += sin(_ghostFlickerPhase * 3.0) * 0.035;
    }

    // ── Wing Fold ─────────────────────────────────────────────────────────────

    // Ease the wing response as well, matching the softer hold/release motion.
    _wingFold = MathUtils.lerp(_wingFold, isHolding ? 1.0 : 0.0, 0.10);

    // ── Edge Tracking ─────────────────────────────────────────────────────────

    _wasHolding = isHolding;
  }

  // ── Soft Ceiling Handling ───────────────────────────────────────────────────

  void _handleCeiling(double dt) {
    if (position.y >= GameConfig.ceilingSoftY) {
      _ceilingWasInSoftZone = false;
      return;
    }

    // Inside soft zone: progressive aerodynamic resistance while moving upward.
    if (_velocityY < 0) {
      if (position.y <= GameConfig.ceilingY) {
        // Hard ceiling hit — clamp and stall dip.
        position.y = GameConfig.ceilingY;
        if (!_ceilingWasInSoftZone) {
          _velocityY = GameConfig.ceilingStallPush; // push down
        } else {
          _velocityY = (_velocityY * 0.15 + GameConfig.ceilingStallPush * 0.6)
              .clamp(-20.0, GameConfig.ceilingStallPush);
        }
        _ceilingStallTimer = GameConfig.ceilingDipDuration;
        _ceilingWasInSoftZone = true;
        // Damp oscillation to emphasize stall.
        _oscillationStrength *= 0.4;
        // Visual puff could be spawned here (reuse scale effect).
        _playCeilingStallEffect();
      } else {
        // Soft resistance: lerp upward velocity toward mild downward drift.
        final t = (GameConfig.ceilingSoftY - position.y) /
            (GameConfig.ceilingSoftY - GameConfig.ceilingY); // 0..1
        final damping = GameConfig.ceilingResistanceDamping * t;
        _velocityY = MathUtils.lerp(
          _velocityY,
          GameConfig.ceilingStallPush * 0.12 * t,
          (damping * dt * 60).clamp(0.0, 0.85),
        );
        // Also gently push position down if very close to ceiling.
        position.y += GameConfig.ceilingStallPush * t * dt * 0.18;
        position.y = position.y.clamp(GameConfig.ceilingY, double.infinity);
        if (t > 0.7 && _ceilingStallTimer <= 0) {
          _ceilingStallTimer = GameConfig.ceilingDipDuration * 0.35;
        }
      }
    } else {
      // Already falling — allow exit but keep clamp.
      if (position.y < GameConfig.ceilingY) {
        position.y = GameConfig.ceilingY;
      }
    }
  }

  void _playCeilingStallEffect() {
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2(1.08, 0.92),
        EffectController(
          duration: GameConfig.ceilingDipDuration / 2,
          reverseDuration: GameConfig.ceilingDipDuration / 2,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
      ),
    );
  }

  void _playSnapBurstEffect() {
    // Quick scale pop + flash already handled via _triggerSnapFlash.
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2.all(1.18),
        EffectController(duration: 0.07, reverseDuration: 0.07),
      ),
    );
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

    // Ceiling stall dip: gentle nose-down while stalling at ceiling.
    if (_ceilingStallTimer > 0) {
      final t = _ceilingStallTimer / GameConfig.ceilingDipDuration;
      pitchTarget += GameConfig.ceilingDipAngle * t;
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
    _ceilingStallTimer = 0.0;
    _ceilingWasInSoftZone = false;
    _snapFlashTimer = 0.0;
    _inThermal = false;
    _shieldActive = false;
    _ghostActive = false;
    _magnetActive = false;
    _coinRushActive = false;
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
    _ceilingStallTimer = 0.0;
    _ceilingWasInSoftZone = false;
    _snapFlashTimer = 0.0;
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

  /// Quick pulse + brighten when the ghost plane phases through an obstacle.
  void playGhostPhaseAnimation() {
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2.all(1.22),
        EffectController(duration: 0.06, reverseDuration: 0.06),
      ),
    );
    _ghostFlickerPhase += pi; // flash brighter on phase
  }

  /// Brief green swirl when Crane brushes off a branch.
  void playBranchBrushAnimation() {
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2.all(1.18),
        EffectController(duration: 0.07, reverseDuration: 0.12),
      ),
    );
    // Spin a little
    add(
      RotateEffect.by(
        0.45,
        EffectController(duration: 0.08, reverseDuration: 0.08),
      ),
    );
  }

  Vector2 get worldPosition => absolutePosition;

  /// Current lateral (X) velocity in px/s — used by the game-feel camera
  /// banking and paper-crease trigger. Positive = rightward.
  double get horizontalVelocity => _velocityX;

  /// Current vertical (Y) velocity in px/s — positive = falling downward.
  /// Used to drive the wind-rush volume/pitch and the speed-streak overlay.
  double get verticalVelocity => _velocityY;

  /// World-space axis-aligned rect of the collision hitbox — used by
  /// obstacles to compute hitbox-edge clearance for tiered near-misses.
  Rect get worldAabbRect {
    final scale = planeType.hitboxScaleOverride ?? GameConfig.planeHitboxScale;
    final hbSize = size * scale;
    return Rect.fromCenter(
      center: position.toOffset(),
      width: hbSize.x,
      height: hbSize.y,
    );
  }
}
