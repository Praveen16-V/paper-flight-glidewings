import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../core/utils/noise.dart';
import '../../providers/game_session_provider.dart';
import '../paper_flight_game.dart';
import 'plane_trail_component.dart';

/// The player's paper plane.
///
/// Physics model:
///   HOLD: eases velocityY -> liftCruiseSpeed (-95 px/s).
///   RELEASE: preserves full momentum, coasting under glideGravity (0.55)
///            before tipping into full fall (1.0).
///   OSCILLATION: sinusoidal air undulation (10 px/s @ 0.8 Hz) fades in after release.
///   SNAP BURST: upward paper-snap kick (-252 px/s).
///   CEILING: soft resistance zone (64px) -> hard clamp (40px) with stall dip.
///
/// Visual & Rendering features:
///   - Dynamic banking into lateral velocityX (capped at 12°). Glider banks slower.
///   - Per-type origami silhouettes (Dart, Glider, Stunt Fold, Crane, Stealth Jet,
///     Origami Butterfly, Paper Bomber, Interceptor, Soaring Albatross,
///     Classic Biplane, Origami Shuriken, Paper Rocket).
///   - 3-level upgrade tree perks & stats scaling.
///   - Secondary Perlin wing flex wobble on top of hold/release fold.
///   - Thermal breathing scale pulse while riding updrafts.
///   - Edge curl & crumple damage state after near-miss passes (heals over time).
///   - Procedural paper grain texture & diffuse shading (not flat solid colors).
///   - Top-left directional lighting with gradient fold shadows and dual-ridge creases.
///   - Night biome forward headlamp projector cone & aviation wing nav lights.
///   - Active In-Flight Visuals with distinct pulse channels (Shield facets & cracks,
///     Magnet orbiting particles & flux arcs, Ghost trailing after-images & wobble,
///     SlowMo stretched blur & time lines, Coin Rush Saturn ring of gold coins & dust emitters,
///     Stacking VFX resonant interlacing, Double Score jet exhaust, Shrink micro-fold,
///     Wind Caller compass, Decoy Clones, Black Hole vortex, Turbo Dash blazing plasma).
class PlaneComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  PlaneComponent({
    required this.game,
    required this.planeType,
    this.paperSkin = PaperSkin.plain,
    this.planeLevel = 1,
  }) : super(
          size: Vector2(48, 32),
          anchor: Anchor.center,
        );

  final PaperFlightGame game;
  PlaneType planeType;
  PaperSkin paperSkin;
  int planeLevel;

  // ── Physics State ──────────────────────────────────────────────────────────

  double _velocityY = 0.0; // px/s, positive = downward
  double _velocityX = 0.0; // px/s, positive = rightward

  // Hold-state tracking for edge detection.
  bool _wasHolding = false;

  // Glide arc state.
  bool _glideArcActive = false;

  // Oscillation state.
  double _oscillationPhase = 0.0;    // radians, ticks every frame
  double _oscillationStrength = 0.0; // [0,1], ramps up after release

  // Ceiling stall state.
  double _ceilingStallTimer = 0.0; // seconds remaining in stall dip
  bool _ceilingWasInSoftZone = false;

  // ── Visual & Animation State ───────────────────────────────────────────────

  bool _isAlive = true;

  /// Wing-fold amount [0 = fully spread (gliding), 1 = folded up (holding)].
  double _wingFold = 0.0;

  /// Total elapsed time in seconds.
  double _animTime = 0.0;

  /// Procedural ValueNoise generator for secondary aerodynamic wing flutter.
  final ValueNoise _noise = ValueNoise(seed: 2026);

  /// Near-miss crumple / damage intensity [0.0 = pristine, 1.0 = curled/crumpled].
  double _crumpleAmount = 0.0;

  /// Thermal breathing blend factor [0 = none, 1 = full buoyancy breathing].
  double _thermalBreathFactor = 0.0;

  /// True while the plane's wind lane is a thermal updraft.
  bool _inThermal = false;
  bool get isInThermal => _inThermal;

  // ── Active Power-up Visual State ───────────────────────────────────────────

  bool _shieldActive = false;
  bool _ghostActive = false;
  bool _magnetActive = false;
  bool _coinRushActive = false;
  bool _slowMoActive = false;
  bool _doubleScoreActive = false;
  bool _shrinkActive = false;
  bool _windCallerActive = false;
  bool _decoyCloneActive = false;
  bool _blackHoleActive = false;
  bool _turboDashActive = false;

  // ── Distinct Pulse Channels ───────────────────────────────────────────────
  double _shieldPhase = 0.0;     // 1.2 Hz breathing
  double _ghostPhase = 0.0;      // 8.0 Hz rapid ethereal flicker
  double _magnetAngle = 0.0;     // 36 deg/s rotation
  double _coinRushPhase = 0.0;   // 3.0 Hz
  double _slowMoPhase = 0.0;     // 1.0 Hz slow tick
  double _doubleScorePhase = 0.0;// 12.0 Hz jet exhaust flutter
  double _turboDashPhase = 0.0;  // 20.0 Hz blaze
  double _blackHoleAngle = 0.0;  // 180 deg/s cosmic vortex

  double _shieldHitRippleTimer = 0.0;
  double _ghostFlickerPhase = 0.0;
  double _snapFlashTimer = 0.0;

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

    _trail = PlaneTrailComponent(plane: this);
    add(_trail);

    final scale = planeType.hitboxScaleForLevel(planeLevel) ??
        planeType.hitboxScaleOverride ??
        GameConfig.planeHitboxScale;
    final hbSize = size * scale;
    _hitbox = RectangleHitbox(
      size: hbSize,
      position: (size - hbSize) / 2,
    );
    add(_hitbox);

    await super.onLoad();
  }

  void syncHitboxForPlaneType(PlaneType newType) {
    planeType = newType;
    final baseScale = newType.hitboxScaleForLevel(planeLevel) ??
        newType.hitboxScaleOverride ??
        GameConfig.planeHitboxScale;
    final scale = _shrinkActive ? GameConfig.shrinkHitboxScale : baseScale;
    final hbSize = size * scale;
    _hitbox.size = hbSize;
    _hitbox.position = (size - hbSize) / 2;
  }

  void syncSkin(PaperSkin newSkin) {
    paperSkin = newSkin;
  }

  void syncLevel(int newLevel) {
    planeLevel = newLevel;
    syncHitboxForPlaneType(planeType);
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final baseColor = Color(paperSkin.baseColorHex);
    final Color planeColor = paperSkin == PaperSkin.plain
        ? const Color(0xFFF5A623)
        : baseColor;

    final w = size.x;
    final h = size.y;

    // Ghost: translucent plane
    double ghostOpacity = 1.0;
    if (_ghostActive) {
      final flicker = 0.52 + 0.22 * math.sin(_ghostPhase);
      ghostOpacity = flicker.clamp(0.35, 0.85);
    }

    // ── Thermal Breathing Scale ──────────────────────────────────────────────
    final breathSin = math.sin(_animTime * 5.0);
    var breathScale = 1.0 + 0.042 * breathSin * _thermalBreathFactor;
    if (_shrinkActive) breathScale *= GameConfig.shrinkVisualScale;

    // ── Secondary Wing Flex Wobble on top of hold/release fold ───────────────
    final flexNoise = _noise.noise1d(_animTime * 3.8);
    final wingFlexWobble = flexNoise * 0.07 * (1.0 - _wingFold * 0.4);
    final butterflyFlap = planeType == PlaneType.butterfly
        ? math.sin(_animTime * 10.0) * 0.35 * (1.0 - _wingFold * 0.5)
        : 0.0;
    final effectiveFold =
        (_wingFold + wingFlexWobble + butterflyFlap).clamp(0.0, 1.0);

    // ── Night Lighting: Forward Projector Headlamp Beam ──────────────────────
    if (game.biomeManager.currentBiome == Biome.night) {
      _drawNightHeadlamp(canvas, w, h);
    }

    // ── Ghost After-Images Trailing ──────────────────────────────────────────
    if (_ghostActive) {
      _drawGhostAfterImages(canvas, w, h, effectiveFold, planeColor);
    }

    // ── Slow-Mo Optical Stretched Blur ───────────────────────────────────────
    if (_slowMoActive) {
      _drawSlowMoAfterImage(canvas, w, h, effectiveFold, planeColor);
    }

    // ── Base Canvas Transform ────────────────────────────────────────────────
    canvas.save();
    canvas.translate(w / 2, h / 2);
    if (breathScale != 1.0) {
      canvas.scale(breathScale, breathScale);
    }
    canvas.rotate(-math.pi / 2);
    canvas.translate(-w / 2, -h / 2);

    // 1. Soft Drop Shadow
    canvas.save();
    canvas.translate(1.5, 2.5);
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill;
    _drawPlaneShape(canvas, shadowPaint, w, h, effectiveFold,
        isShadow: true, planeColor: planeColor, opacity: ghostOpacity);
    canvas.restore();

    // 2. Main Plane Body
    final mainPaint = Paint()
      ..color = planeColor.withOpacity(ghostOpacity)
      ..style = PaintingStyle.fill;
    _drawPlaneShape(canvas, mainPaint, w, h, effectiveFold,
        isShadow: false, planeColor: planeColor, opacity: ghostOpacity);

    // 3. Procedural Paper Grain & Texture Multiply Layer
    _drawPaperGrainTexture(canvas, w, h, planeColor, effectiveFold);

    // 4. Directional Top-Left Highlight & Dual Crease Lines
    _drawLightingAndCreases(canvas, w, h, planeColor, effectiveFold);

    // 5. Edge Curl & Crumple Damage Overlay
    if (_crumpleAmount > 0.01) {
      _drawCrumpleDamage(canvas, w, h, _crumpleAmount);
    }

    canvas.restore();

    super.render(canvas);

    // ── Paper-skin overlay patterns ──────────────────────────────────────────
    _drawSkinOverlay(canvas, w, h);

    // ── Aviation Wing Navigation Lights ──────────────────────────────────────
    _drawWingNavLights(canvas, w, h);

    // ── Active In-Flight Power-Up Visuals ────────────────────────────────────
    _drawPowerUpOverlays(canvas, w, h);

    // ── Snap charge ring ─────────────────────────────────────────────────────
    _drawSnapChargeRing(canvas, w, h);
  }

  // ── Silhouette per type ────────────────────────────────────────────────────

  void _drawPlaneShape(
    Canvas canvas,
    Paint basePaint,
    double w,
    double h,
    double wingFold, {
    required bool isShadow,
    required Color planeColor,
    required double opacity,
  }) {
    switch (planeType) {
      case PlaneType.dart:
        _drawDartSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.glider:
        _drawGliderSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.stuntFold:
        _drawStuntFoldSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.crane:
        _drawCraneSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.stealthJet:
        _drawStealthJetSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.butterfly:
        _drawButterflySilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.bomber:
        _drawBomberSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.interceptor:
        _drawInterceptorSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.albatross:
        _drawAlbatrossSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.biplane:
        _drawBiplaneSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.ninjaStar:
        _drawNinjaStarSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
      case PlaneType.rocket:
        _drawRocketSilhouette(canvas, basePaint, w, h, wingFold,
            isShadow: isShadow, planeColor: planeColor, opacity: opacity);
        break;
    }
  }

  void _drawDartSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final spreadY = h * 0.08;
    final topWingY = (h * 0.14) * (1.0 - wingFold) - spreadY * (1.0 - wingFold);
    final botWingY = h - (h * 0.14) * (1.0 - wingFold) + spreadY * (1.0 - wingFold);
    const noseX = 2.0;

    final upperWing = Path()..moveTo(w + noseX, h / 2)..lineTo(w * 0.32, h / 2)..lineTo(0, topWingY)..close();
    final lowerWing = Path()..moveTo(w + noseX, h / 2)..lineTo(w * 0.32, h / 2)..lineTo(0, botWingY)..close();
    final bodyKeel = Path()..moveTo(w + noseX, h / 2)..lineTo(w * 0.32, h / 2)..lineTo(0, h / 2)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(bodyKeel, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, w + noseX, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, w + noseX, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint); canvas.drawPath(bodyKeel, paint);
    }
  }

  void _drawGliderSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final spreadY = h * 0.22;
    final topWingY = -spreadY * (1.0 - wingFold);
    final botWingY = h + spreadY * (1.0 - wingFold);
    final noseX = w + 4.0;

    final upperWing = Path()..moveTo(noseX, h / 2)..quadraticBezierTo(w * 0.65, topWingY + 2, w * 0.05, topWingY)..lineTo(0, topWingY + 5)..lineTo(w * 0.22, h / 2)..close();
    final lowerWing = Path()..moveTo(noseX, h / 2)..quadraticBezierTo(w * 0.65, botWingY - 2, w * 0.05, botWingY)..lineTo(0, botWingY - 5)..lineTo(w * 0.22, h / 2)..close();
    final fuselage = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.22, h / 2)..lineTo(0, h / 2)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(fuselage, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, noseX, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, noseX, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint); canvas.drawPath(fuselage, paint);
      _drawGliderRibs(canvas, w, h, topWingY, botWingY);
    }
  }

  void _drawGliderRibs(Canvas canvas, double w, double h, double topY, double botY) {
    final ribLit = Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    final ribShadow = Paint()..color = Colors.black.withOpacity(0.25)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    for (final rx in [w * 0.68, w * 0.46, w * 0.25]) {
      final upperY = MathUtils.lerp(h / 2, topY, (w - rx) / w);
      final lowerY = MathUtils.lerp(h / 2, botY, (w - rx) / w);
      canvas.drawLine(Offset(rx, h / 2), Offset(rx - 3, upperY), ribLit);
      canvas.drawLine(Offset(rx, h / 2), Offset(rx - 3, lowerY), ribShadow);
    }
  }

  void _drawStuntFoldSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final topWingY = (h * 0.05) * (1.0 - wingFold);
    final botWingY = h - (h * 0.05) * (1.0 - wingFold);
    final noseX = w + 3.0;

    final upperWing = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.55, h / 2)..lineTo(w * 0.12, topWingY)..lineTo(0, topWingY + 4)..lineTo(w * 0.28, h / 2)..close();
    final lowerWing = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.55, h / 2)..lineTo(w * 0.12, botWingY)..lineTo(0, botWingY - 4)..lineTo(w * 0.28, h / 2)..close();
    final upperCanard = Path()..moveTo(w * 0.88, h / 2)..lineTo(w * 0.70, h * 0.08)..lineTo(w * 0.65, h / 2)..close();
    final lowerCanard = Path()..moveTo(w * 0.88, h / 2)..lineTo(w * 0.70, h * 0.92)..lineTo(w * 0.65, h / 2)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(upperCanard, paint); canvas.drawPath(lowerCanard, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, noseX, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, noseX, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint); canvas.drawPath(upperCanard, litPaint); canvas.drawPath(lowerCanard, shadowWingPaint);
      final tipPaint = Paint()..color = Color.lerp(planeColor, Colors.white, 0.45)!.withOpacity(opacity)..style = PaintingStyle.fill;
      final tipShadow = Paint()..color = Color.lerp(planeColor, Colors.black, 0.40)!.withOpacity(opacity)..style = PaintingStyle.fill;
      canvas.drawPath(Path()..moveTo(w * 0.12, topWingY)..lineTo(0, topWingY + 4)..lineTo(w * 0.04, topWingY - 3)..close(), tipPaint);
      canvas.drawPath(Path()..moveTo(w * 0.12, botWingY)..lineTo(0, botWingY - 4)..lineTo(w * 0.04, botWingY + 3)..close(), tipShadow);
    }
  }

  void _drawCraneSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final topWingY = (h * 0.02) * (1.0 - wingFold) - 4 * (1.0 - wingFold);
    final botWingY = h - (h * 0.02) * (1.0 - wingFold) + 4 * (1.0 - wingFold);
    final headX = w + 14.0;

    final neckPath = Path()..moveTo(w * 0.65, h / 2)..lineTo(w * 0.95, h / 2 - 2)..lineTo(headX, h / 2 - 1)..lineTo(w * 0.92, h / 2 + 2)..lineTo(w * 0.65, h / 2)..close();
    final upperBaseWing = Path()..moveTo(w * 0.65, h / 2)..lineTo(w * 0.25, topWingY)..lineTo(w * 0.15, h / 2)..close();
    final upperFeatherWing = Path()..moveTo(w * 0.50, h / 2)..lineTo(w * 0.10, topWingY + 4)..lineTo(0, h / 2)..close();
    final lowerBaseWing = Path()..moveTo(w * 0.65, h / 2)..lineTo(w * 0.25, botWingY)..lineTo(w * 0.15, h / 2)..close();
    final lowerFeatherWing = Path()..moveTo(w * 0.50, h / 2)..lineTo(w * 0.10, botWingY - 4)..lineTo(0, h / 2)..close();
    final saddle = Path()..moveTo(w * 0.65, h / 2)..lineTo(w * 0.40, h * 0.28)..lineTo(w * 0.15, h / 2)..lineTo(w * 0.40, h * 0.72)..close();
    final tailPath = Path()..moveTo(w * 0.25, h / 2)..lineTo(-w * 0.12, h / 2)..lineTo(0, h / 2 + 1.5)..close();

    if (isShadow) {
      canvas.drawPath(neckPath, paint); canvas.drawPath(upperBaseWing, paint); canvas.drawPath(upperFeatherWing, paint); canvas.drawPath(lowerBaseWing, paint); canvas.drawPath(lowerFeatherWing, paint); canvas.drawPath(saddle, paint); canvas.drawPath(tailPath, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, headX, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, headX, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperFeatherWing, litPaint); canvas.drawPath(upperBaseWing, litPaint); canvas.drawPath(lowerFeatherWing, shadowWingPaint); canvas.drawPath(lowerBaseWing, shadowWingPaint); canvas.drawPath(tailPath, shadowWingPaint);
      canvas.drawPath(saddle, Paint()..color = Color.lerp(planeColor, Colors.white, 0.18)!.withOpacity(opacity)..style = PaintingStyle.fill);
      canvas.drawPath(neckPath, litPaint);
      canvas.drawPath(Path()..moveTo(w + 10, h / 2 - 1.5)..lineTo(headX, h / 2 - 1)..lineTo(w + 10, h / 2 + 1.5)..close(), Paint()..color = const Color(0xFFFFD54F).withOpacity(opacity)..style = PaintingStyle.fill);
    }
  }

  void _drawStealthJetSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final topWingY = (h * 0.10) * (1.0 - wingFold);
    final botWingY = h - (h * 0.10) * (1.0 - wingFold);
    final noseX = w + 5.0;

    final upperWing = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.70, h * 0.32)..lineTo(w * 0.05, topWingY)..lineTo(w * 0.15, h / 2)..close();
    final lowerWing = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.70, h * 0.68)..lineTo(w * 0.05, botWingY)..lineTo(w * 0.15, h / 2)..close();
    final upperFin = Path()..moveTo(w * 0.32, h * 0.36)..lineTo(w * 0.08, topWingY - 4)..lineTo(w * 0.02, topWingY - 1)..lineTo(w * 0.20, h * 0.36)..close();
    final lowerFin = Path()..moveTo(w * 0.32, h * 0.64)..lineTo(w * 0.08, botWingY + 4)..lineTo(w * 0.02, botWingY + 1)..lineTo(w * 0.20, h * 0.64)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(upperFin, paint); canvas.drawPath(lowerFin, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, noseX, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, noseX, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint);
      canvas.drawPath(upperFin, Paint()..color = Color.lerp(planeColor, Colors.white, 0.32)!.withOpacity(opacity)..style = PaintingStyle.fill);
      canvas.drawPath(lowerFin, Paint()..color = Color.lerp(planeColor, Colors.black, 0.38)!.withOpacity(opacity)..style = PaintingStyle.fill);
      final intakeDark = Paint()..color = const Color(0xFF1E272C).withOpacity(opacity)..style = PaintingStyle.fill;
      canvas.drawPath(Path()..moveTo(w * 0.62, h / 2 - 2)..lineTo(w * 0.48, h * 0.26)..lineTo(w * 0.40, h / 2 - 2)..close(), intakeDark);
      canvas.drawPath(Path()..moveTo(w * 0.62, h / 2 + 2)..lineTo(w * 0.48, h * 0.74)..lineTo(w * 0.40, h / 2 + 2)..close(), intakeDark);
      final canopy = Path()..moveTo(w * 0.74, h / 2)..lineTo(w * 0.60, h / 2 - 3.5)..lineTo(w * 0.46, h / 2)..lineTo(w * 0.60, h / 2 + 3.5)..close();
      canvas.drawPath(canopy, Paint()..color = const Color(0xFFFFD54F).withOpacity(0.55 * opacity)..style = PaintingStyle.fill);
    }
  }

  void _drawButterflySilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final spreadY = h * 0.28;
    final topWingY = -spreadY * (1.0 - wingFold);
    final botWingY = h + spreadY * (1.0 - wingFold);

    final upperForewing = Path()..moveTo(w * 0.85, h / 2)..quadraticBezierTo(w * 0.65, topWingY - 4, w * 0.25, topWingY)..quadraticBezierTo(w * 0.10, topWingY + 6, w * 0.35, h / 2)..close();
    final upperHindwing = Path()..moveTo(w * 0.35, h / 2)..quadraticBezierTo(w * 0.05, topWingY + 10, 0, h / 2)..close();
    final lowerForewing = Path()..moveTo(w * 0.85, h / 2)..quadraticBezierTo(w * 0.65, botWingY + 4, w * 0.25, botWingY)..quadraticBezierTo(w * 0.10, botWingY - 6, w * 0.35, h / 2)..close();
    final lowerHindwing = Path()..moveTo(w * 0.35, h / 2)..quadraticBezierTo(w * 0.05, botWingY - 10, 0, h / 2)..close();
    final body = Path()..moveTo(w * 0.90, h / 2)..lineTo(w * 0.20, h / 2 - 2)..lineTo(0, h / 2)..lineTo(w * 0.20, h / 2 + 2)..close();

    if (isShadow) {
      canvas.drawPath(upperForewing, paint); canvas.drawPath(upperHindwing, paint); canvas.drawPath(lowerForewing, paint); canvas.drawPath(lowerHindwing, paint); canvas.drawPath(body, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, w, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, w, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperForewing, litPaint); canvas.drawPath(upperHindwing, litPaint); canvas.drawPath(lowerForewing, shadowWingPaint); canvas.drawPath(lowerHindwing, shadowWingPaint); canvas.drawPath(body, paint);
      final ant = Paint()..color = Colors.white.withOpacity(0.6 * opacity)..strokeWidth = 0.9;
      canvas.drawLine(Offset(w * 0.88, h / 2 - 1), Offset(w + 6, h / 2 - 5), ant);
      canvas.drawLine(Offset(w * 0.88, h / 2 + 1), Offset(w + 6, h / 2 + 5), ant);
    }
  }

  void _drawBomberSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final topWingY = (h * 0.04) * (1.0 - wingFold);
    final botWingY = h - (h * 0.04) * (1.0 - wingFold);

    final upperWing = Path()..moveTo(w * 0.88, h / 2)..lineTo(w * 0.50, topWingY)..lineTo(w * 0.08, topWingY + 3)..lineTo(w * 0.20, h / 2)..close();
    final lowerWing = Path()..moveTo(w * 0.88, h / 2)..lineTo(w * 0.50, botWingY)..lineTo(w * 0.08, botWingY - 3)..lineTo(w * 0.20, h / 2)..close();
    final fuselage = Path()..moveTo(w + 3, h / 2)..lineTo(w * 0.75, h / 2 - 6)..lineTo(0, h / 2 - 4)..lineTo(0, h / 2 + 4)..lineTo(w * 0.75, h / 2 + 6)..close();
    final upperTailFin = Path()..moveTo(w * 0.22, topWingY + 3)..lineTo(w * 0.08, topWingY - 4)..lineTo(0, topWingY + 3)..close();
    final lowerTailFin = Path()..moveTo(w * 0.22, botWingY - 3)..lineTo(w * 0.08, botWingY + 4)..lineTo(0, botWingY - 3)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(fuselage, paint); canvas.drawPath(upperTailFin, paint); canvas.drawPath(lowerTailFin, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, w, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, w, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint); canvas.drawPath(fuselage, litPaint);
      canvas.drawPath(upperTailFin, litPaint); canvas.drawPath(lowerTailFin, shadowWingPaint);
      final seam = Paint()..color = Colors.black.withOpacity(0.35 * opacity)..strokeWidth = 0.8;
      canvas.drawLine(Offset(w * 0.65, h / 2 - 3), Offset(w * 0.35, h / 2 - 3), seam);
      canvas.drawLine(Offset(w * 0.65, h / 2 + 3), Offset(w * 0.35, h / 2 + 3), seam);
    }
  }

  void _drawInterceptorSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final topWingY = (h * 0.12) * (1.0 - wingFold);
    final botWingY = h - (h * 0.12) * (1.0 - wingFold);
    final noseX = w + 7.0;

    final upperWing = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.65, h * 0.36)..lineTo(0, topWingY)..lineTo(w * 0.18, h / 2)..close();
    final lowerWing = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.65, h * 0.64)..lineTo(0, botWingY)..lineTo(w * 0.18, h / 2)..close();
    final upperCanard = Path()..moveTo(w * 0.85, h / 2)..lineTo(w * 0.70, h * 0.12)..lineTo(w * 0.62, h / 2)..close();
    final lowerCanard = Path()..moveTo(w * 0.85, h / 2)..lineTo(w * 0.70, h * 0.88)..lineTo(w * 0.62, h / 2)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(upperCanard, paint); canvas.drawPath(lowerCanard, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, noseX, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, noseX, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint); canvas.drawPath(upperCanard, litPaint); canvas.drawPath(lowerCanard, shadowWingPaint);
      final intake = Paint()..color = const Color(0xFF263238).withOpacity(opacity)..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(w * 0.42, h / 2 - 3.5, 10, 2), intake);
      canvas.drawRect(Rect.fromLTWH(w * 0.42, h / 2 + 1.5, 10, 2), intake);
    }
  }

  void _drawAlbatrossSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final spreadY = h * 0.32;
    final topWingY = -spreadY * (1.0 - wingFold);
    final botWingY = h + spreadY * (1.0 - wingFold);
    final billX = w + 8.0;

    final upperWing = Path()..moveTo(w * 0.75, h / 2)..quadraticBezierTo(w * 0.55, topWingY - 3, w * 0.05, topWingY)..lineTo(0, topWingY + 4)..lineTo(w * 0.15, h / 2)..close();
    final lowerWing = Path()..moveTo(w * 0.75, h / 2)..quadraticBezierTo(w * 0.55, botWingY + 3, w * 0.05, botWingY)..lineTo(0, botWingY - 4)..lineTo(w * 0.15, h / 2)..close();
    final body = Path()..moveTo(billX, h / 2)..lineTo(w * 0.80, h / 2 - 2)..lineTo(0, h / 2 - 1.5)..lineTo(0, h / 2 + 1.5)..lineTo(w * 0.80, h / 2 + 2)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(body, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, billX, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, billX, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint); canvas.drawPath(body, paint);
      final ribLit = Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = 0.7..style = PaintingStyle.stroke;
      for (final rx in [w * 0.65, w * 0.48, w * 0.32, w * 0.16]) {
        final upperY = MathUtils.lerp(h / 2, topWingY, (w - rx) / w);
        final lowerY = MathUtils.lerp(h / 2, botWingY, (w - rx) / w);
        canvas.drawLine(Offset(rx, h / 2), Offset(rx - 2, upperY), ribLit);
        canvas.drawLine(Offset(rx, h / 2), Offset(rx - 2, lowerY), ribLit);
      }
    }
  }

  void _drawBiplaneSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final topWingY = (h * 0.08) * (1.0 - wingFold);
    final botWingY = h - (h * 0.08) * (1.0 - wingFold);
    final upperWing = Path()..moveTo(w * 0.85, h / 2)..lineTo(w * 0.65, topWingY)..lineTo(w * 0.15, topWingY)..lineTo(w * 0.25, h / 2)..close();
    final lowerWing = Path()..moveTo(w * 0.85, h / 2)..lineTo(w * 0.65, botWingY)..lineTo(w * 0.15, botWingY)..lineTo(w * 0.25, h / 2)..close();
    final cowl = Path()..moveTo(w + 2, h / 2)..lineTo(w * 0.80, h / 2 - 4)..lineTo(0, h / 2 - 2)..lineTo(0, h / 2 + 2)..lineTo(w * 0.80, h / 2 + 4)..close();

    if (isShadow) {
      canvas.drawPath(upperWing, paint); canvas.drawPath(lowerWing, paint); canvas.drawPath(cowl, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topWingY, w, h / 2 - topWingY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, w, botWingY - h / 2), planeColor, opacity);
      canvas.drawPath(upperWing, litPaint); canvas.drawPath(lowerWing, shadowWingPaint); canvas.drawPath(cowl, paint);
      final strut = Paint()..color = const Color(0xFF5D4037).withOpacity(opacity)..strokeWidth = 1.2;
      canvas.drawLine(Offset(w * 0.35, topWingY), Offset(w * 0.35, h / 2 - 4), strut);
      canvas.drawLine(Offset(w * 0.35, botWingY), Offset(w * 0.35, h / 2 + 4), strut);
    }
  }

  void _drawNinjaStarSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.45;
    final b1 = Path()..moveTo(cx, cy)..lineTo(cx + r, cy)..lineTo(cx + r * 0.4, cy - r * 0.5)..close();
    final b2 = Path()..moveTo(cx, cy)..lineTo(cx, cy - r)..lineTo(cx - r * 0.5, cy - r * 0.4)..close();
    final b3 = Path()..moveTo(cx, cy)..lineTo(cx - r, cy)..lineTo(cx - r * 0.4, cy + r * 0.5)..close();
    final b4 = Path()..moveTo(cx, cy)..lineTo(cx, cy + r)..lineTo(cx + r * 0.5, cy + r * 0.4)..close();

    if (isShadow) {
      canvas.drawPath(b1, paint); canvas.drawPath(b2, paint); canvas.drawPath(b3, paint); canvas.drawPath(b4, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromCircle(center: Offset(cx, cy), radius: r), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromCircle(center: Offset(cx, cy), radius: r), planeColor, opacity);
      canvas.drawPath(b1, litPaint); canvas.drawPath(b2, litPaint); canvas.drawPath(b3, shadowWingPaint); canvas.drawPath(b4, shadowWingPaint);
      canvas.drawCircle(Offset(cx, cy), 3.5, Paint()..color = Color.lerp(planeColor, Colors.white, 0.4)!.withOpacity(opacity)..style = PaintingStyle.fill);
    }
  }

  void _drawRocketSilhouette(Canvas canvas, Paint paint, double w, double h, double wingFold, {required bool isShadow, required Color planeColor, required double opacity}) {
    final topFinY = (h * 0.08) * (1.0 - wingFold);
    final botFinY = h - (h * 0.08) * (1.0 - wingFold);
    final noseX = w + 6.0;

    final fuselage = Path()..moveTo(noseX, h / 2)..lineTo(w * 0.65, h / 2 - 5)..lineTo(w * 0.12, h / 2 - 5)..lineTo(w * 0.05, h / 2)..lineTo(w * 0.12, h / 2 + 5)..lineTo(w * 0.65, h / 2 + 5)..close();
    final upperFin = Path()..moveTo(w * 0.40, h / 2 - 5)..lineTo(w * 0.05, topFinY)..lineTo(w * 0.12, h / 2 - 5)..close();
    final lowerFin = Path()..moveTo(w * 0.40, h / 2 + 5)..lineTo(w * 0.05, botFinY)..lineTo(w * 0.12, h / 2 + 5)..close();

    if (isShadow) {
      canvas.drawPath(fuselage, paint); canvas.drawPath(upperFin, paint); canvas.drawPath(lowerFin, paint);
    } else {
      final litPaint = _createLitWingPaint(Rect.fromLTWH(0, topFinY, noseX, h / 2 - topFinY), planeColor, opacity);
      final shadowWingPaint = _createShadedWingPaint(Rect.fromLTWH(0, h / 2, noseX, botFinY - h / 2), planeColor, opacity);
      canvas.drawPath(upperFin, litPaint); canvas.drawPath(lowerFin, shadowWingPaint); canvas.drawPath(fuselage, litPaint);
      canvas.drawPath(Path()..moveTo(noseX, h / 2)..lineTo(w * 0.82, h / 2 - 3.8)..lineTo(w * 0.82, h / 2 + 3.8)..close(), Paint()..color = const Color(0xFFFF1744).withOpacity(opacity)..style = PaintingStyle.fill);
      canvas.drawRect(Rect.fromLTWH(0, h / 2 - 3, 5, 6), Paint()..color = const Color(0xFF37474F).withOpacity(opacity)..style = PaintingStyle.fill);
    }
  }

  // ── Procedural Paper Texture Layer (Shader-like Multiply Grain) ────────────

  void _drawPaperGrainTexture(Canvas canvas, double w, double h, Color baseColor, double wingFold) {
    final fiberPaint = Paint()..color = Colors.white.withOpacity(0.065)..strokeWidth = 0.5..style = PaintingStyle.stroke;
    final fiberDark = Paint()..color = Colors.black.withOpacity(0.045)..strokeWidth = 0.5..style = PaintingStyle.stroke;

    for (double x = 4; x < w - 2; x += 6.5) {
      canvas.drawLine(Offset(x, h * 0.2), Offset(x + 5, h * 0.8), fiberPaint);
      canvas.drawLine(Offset(x + 2, h * 0.3), Offset(x - 3, h * 0.7), fiberDark);
    }

    final specklePaint = Paint()..color = Colors.white.withOpacity(0.10)..style = PaintingStyle.fill;
    for (final sp in [Offset(w * 0.35, h * 0.35), Offset(w * 0.55, h * 0.65), Offset(w * 0.75, h * 0.48), Offset(w * 0.20, h * 0.70)]) {
      canvas.drawCircle(sp, 0.8, specklePaint);
    }
  }

  // ── Directional Top-Left Lighting & Dual Crease Lines ──────────────────────

  void _drawLightingAndCreases(Canvas canvas, double w, double h, Color baseColor, double wingFold) {
    final specularPaint = Paint()..color = Colors.white.withOpacity(0.38)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.95, h / 2), Offset(w * 0.15, h * 0.18), specularPaint);

    final creaseLit = Paint()..color = Colors.white.withOpacity(0.40)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.25, h / 2 - 0.5), Offset(w, h / 2 - 0.5), creaseLit);

    final creaseShadow = Paint()..color = Colors.black.withOpacity(0.45)..strokeWidth = 0.9..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.25, h / 2 + 0.5), Offset(w, h / 2 + 0.5), creaseShadow);
  }

  // ── Damage / Crumple States (Edge Curl After Near-Miss) ────────────────────

  void _drawCrumpleDamage(Canvas canvas, double w, double h, double crumple) {
    final curlAlpha = (crumple * 0.85).clamp(0.0, 1.0);
    final crinklePaint = Paint()..color = Colors.black.withOpacity(0.35 * curlAlpha)..strokeWidth = 0.9..style = PaintingStyle.stroke;
    final highlightCrinkle = Paint()..color = Colors.white.withOpacity(0.40 * curlAlpha)..strokeWidth = 0.7..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(w * 0.08, h * 0.22), Offset(w * 0.18, h * 0.32), crinklePaint);
    canvas.drawLine(Offset(w * 0.08, h * 0.22), Offset(w * 0.18, h * 0.32), highlightCrinkle);
    canvas.drawLine(Offset(w * 0.06, h * 0.78), Offset(w * 0.16, h * 0.68), crinklePaint);
    canvas.drawLine(Offset(w * 0.06, h * 0.78), Offset(w * 0.16, h * 0.68), highlightCrinkle);

    final dogEar = Path()..moveTo(0, h * 0.20)..lineTo(w * 0.10, h * 0.16)..lineTo(w * 0.06, h * 0.28)..close();
    canvas.drawPath(dogEar, Paint()..color = Colors.black.withOpacity(0.22 * curlAlpha)..style = PaintingStyle.fill);
  }

  // ── Night Lighting: Forward Headlamp Cone ──────────────────────────────────

  void _drawNightHeadlamp(Canvas canvas, double w, double h) {
    final headlampCenter = Offset(w / 2, h / 2 - 12);
    final lampShader = RadialGradient(
      center: Alignment.topCenter,
      radius: 0.9,
      colors: const [Color(0x88FFF8E1), Color(0x30FFE082), Color(0x00FFF8E1)],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: headlampCenter, radius: 140));

    final beamPath = Path()
      ..moveTo(w / 2 - 6, h / 2 - 12)
      ..lineTo(w / 2 - 70, h / 2 - 150)
      ..lineTo(w / 2 + 70, h / 2 - 150)
      ..lineTo(w / 2 + 6, h / 2 - 12)
      ..close();
    canvas.drawPath(beamPath, Paint()..shader = lampShader..style = PaintingStyle.fill);

    final motePaint = Paint()..color = const Color(0x99FFF9C4)..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final mx = w / 2 + math.sin(_animTime * 3.0 + i * 1.5) * 35;
      final my = h / 2 - 40 - (i * 25);
      canvas.drawCircle(Offset(mx, my), 1.2, motePaint);
    }
  }

  // ── Aviation Wing Navigation Lights ────────────────────────────────────────

  void _drawWingNavLights(Canvas canvas, double w, double h) {
    final isNight = game.biomeManager.currentBiome == Biome.night;
    final baseAlpha = isNight ? 1.0 : 0.45;

    final redPos = Offset(w * 0.15, h / 2);
    canvas.drawCircle(redPos, 4.5, Paint()..color = Color.fromRGBO(255, 23, 68, 0.40 * baseAlpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(redPos, 1.6, Paint()..color = Color.fromRGBO(255, 82, 82, 0.90 * baseAlpha)..style = PaintingStyle.fill);

    final greenPos = Offset(w * 0.85, h / 2);
    canvas.drawCircle(greenPos, 4.5, Paint()..color = Color.fromRGBO(0, 230, 118, 0.40 * baseAlpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(greenPos, 1.6, Paint()..color = Color.fromRGBO(105, 240, 174, 0.90 * baseAlpha)..style = PaintingStyle.fill);

    final strobeCycle = _animTime % 1.2;
    final isFlashing = strobeCycle < 0.08 || (strobeCycle > 0.16 && strobeCycle < 0.24);
    if (isFlashing) {
      final strobePos = Offset(w / 2, h / 2 + 10);
      canvas.drawCircle(strobePos, 6.0, Paint()..color = Color.fromRGBO(255, 255, 255, 0.85 * baseAlpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(strobePos, 2.0, Paint()..color = Colors.white..style = PaintingStyle.fill);
    }
  }

  // ── Gradient Factory Helpers ───────────────────────────────────────────────

  Paint _createLitWingPaint(Rect bounds, Color baseColor, double opacity) {
    final litColor = Color.lerp(baseColor, Colors.white, 0.26)!.withOpacity(opacity);
    final midColor = baseColor.withOpacity(opacity);
    return Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [litColor, midColor]).createShader(bounds)..style = PaintingStyle.fill;
  }

  Paint _createShadedWingPaint(Rect bounds, Color baseColor, double opacity) {
    final midColor = baseColor.withOpacity(opacity);
    final shadowColor = Color.lerp(baseColor, Colors.black, 0.28)!.withOpacity(opacity);
    return Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [midColor, shadowColor]).createShader(bounds)..style = PaintingStyle.fill;
  }

  // ── Paper Skin Overlay Patterns ───────────────────────────────────────────

  void _drawSkinOverlay(Canvas canvas, double w, double h) {
    if (paperSkin == PaperSkin.plain) return;
    final pulse = math.sin(_ghostPhase * 0.2) * 0.08 + 0.92;
    switch (paperSkin) {
      case PaperSkin.plain:
        break;
      case PaperSkin.newspaper:
        final inkPaint = Paint()..color = const Color(0xFF3E2723).withOpacity(0.24 * pulse)..strokeWidth = 0.8;
        canvas.drawLine(Offset(w * 0.20, h * 0.28), Offset(w * 0.80, h * 0.28), Paint()..color = const Color(0xFF212121).withOpacity(0.35 * pulse)..strokeWidth = 1.6);
        for (double y = h * 0.36; y < h * 0.82; y += 3.8) {
          final wave = math.sin(y * 4.0 + _animTime * 0.5) * 1.0;
          canvas.drawLine(Offset(w * 0.18 + wave, y), Offset(w * 0.48 - wave, y), inkPaint);
          canvas.drawLine(Offset(w * 0.52 + wave, y), Offset(w * 0.82 - wave, y), inkPaint);
        }
        break;
      case PaperSkin.graphPaper:
        final gridPaint = Paint()..color = const Color(0xFF0288D1).withOpacity(0.25)..strokeWidth = 0.5;
        final majorGrid = Paint()..color = const Color(0xFF01579B).withOpacity(0.40)..strokeWidth = 0.8;
        for (double x = w * 0.12; x < w * 0.88; x += 6.5) {
          canvas.drawLine(Offset(x, h * 0.15), Offset(x, h * 0.85), (x / 6.5).round() % 3 == 0 ? majorGrid : gridPaint);
        }
        for (double y = h * 0.18; y < h * 0.82; y += 6.5) {
          canvas.drawLine(Offset(w * 0.12, y), Offset(w * 0.88, y), (y / 6.5).round() % 3 == 0 ? majorGrid : gridPaint);
        }
        canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: 12), 0, math.pi * 1.5, false, gridPaint..style = PaintingStyle.stroke);
        break;
      case PaperSkin.notebookDoodle:
        final linePaint = Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.38)..strokeWidth = 0.7;
        for (double y = h * 0.28; y < h * 0.82; y += 5.5) {
          canvas.drawLine(Offset(w * 0.18, y), Offset(w * 0.88, y), linePaint);
        }
        canvas.drawLine(Offset(w * 0.26, h * 0.16), Offset(w * 0.26, h * 0.84), Paint()..color = const Color(0xFFFF5252).withOpacity(0.55)..strokeWidth = 1.0);
        final doodle = Paint()..color = const Color(0xFF5D4037).withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 0.9;
        canvas.drawCircle(Offset(w * 0.72, h * 0.38), 3.5 * pulse, doodle);
        canvas.drawLine(Offset(w * 0.72 - 5, h * 0.38), Offset(w * 0.72 + 5, h * 0.38), doodle);
        canvas.drawLine(Offset(w * 0.72, h * 0.38 - 5), Offset(w * 0.72, h * 0.38 + 5), doodle);
        break;
      case PaperSkin.holographicFoil:
        final sweepShift = (_animTime * 35.0) % (w * 1.5);
        final foilPaint = Paint()..shader = LinearGradient(begin: Alignment(-1.5 + (sweepShift / w), -1.0), end: Alignment(0.5 + (sweepShift / w), 1.0), colors: const [Color(0xFFE040FB), Color(0xFF00E5FF), Color(0xFF76FF03), Color(0xFFFFD740), Color(0xFFE040FB)]).createShader(Rect.fromLTWH(0, 0, w, h))..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), foilPaint);
        final glint = Paint()..color = Colors.white.withOpacity(0.75 * pulse);
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(w * (0.3 + i * 0.22), h * (0.35 + math.sin(_animTime * 4.0 + i * 2.0) * 0.2)), 1.6, glint);
        }
        break;
      case PaperSkin.watercolorWash:
        final washA = Paint()..color = const Color(0xFF80DEEA).withOpacity(0.20 + 0.08 * math.sin(_animTime * 2.5))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)..style = PaintingStyle.fill;
        final washB = Paint()..color = const Color(0xFFFF80AB).withOpacity(0.18 + 0.06 * math.cos(_animTime * 2.0))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(w * 0.55, h * 0.42), 15 * pulse, washA);
        canvas.drawCircle(Offset(w * 0.38, h * 0.62), 11, washB);
        break;
      case PaperSkin.goldLeaf:
        final fleckPaint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < 5; i++) {
          final sparkleTTL = (math.sin(_animTime * 7.0 + i * 2.1) * 0.5 + 0.5);
          fleckPaint.color = Color.fromRGBO(255, 215, 0, 0.25 + 0.65 * sparkleTTL);
          canvas.drawCircle(Offset(w * (0.25 + (i * 0.14)), h * (0.30 + ((i * 37) % 40) * 0.01)), 1.2 + sparkleTTL * 1.2, fleckPaint);
        }
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.94, height: h * 0.74), const Radius.circular(5)), Paint()..color = const Color(0xFFFFD700).withOpacity(0.30 * pulse)..style = PaintingStyle.stroke..strokeWidth = 1.4);
        break;
      case PaperSkin.blueprint:
        final bpLine = Paint()..color = Colors.white.withOpacity(0.40)..strokeWidth = 0.7..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(w * 0.15, h * 0.3), Offset(w * 0.85, h * 0.3), bpLine);
        canvas.drawLine(Offset(w * 0.15, h * 0.7), Offset(w * 0.85, h * 0.7), bpLine);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), 8, bpLine);
        break;
      case PaperSkin.receipt:
        final bar = Paint()..color = const Color(0xFF212121).withOpacity(0.32)..style = PaintingStyle.fill;
        for (double x = w * 0.25; x < w * 0.75; x += 3.2) {
          canvas.drawRect(Rect.fromLTWH(x, h * 0.40, (x * 7).toInt() % 2 == 0 ? 2.0 : 1.0, 10), bar);
        }
        break;
      case PaperSkin.carbonFiber:
        final weaveA = Paint()..color = const Color(0xFF424242).withOpacity(0.40)..strokeWidth = 1.0;
        final weaveB = Paint()..color = const Color(0xFF1E1E1E).withOpacity(0.50)..strokeWidth = 1.0;
        for (double d = -w; d < w * 2; d += 4.5) {
          canvas.drawLine(Offset(d, 0), Offset(d + h, h), weaveA);
          canvas.drawLine(Offset(d, h), Offset(d + h, 0), weaveB);
        }
        break;
      case PaperSkin.mangaHalftone:
        final dot = Paint()..color = const Color(0xFF212121).withOpacity(0.22)..style = PaintingStyle.fill;
        for (double x = w * 0.2; x < w * 0.8; x += 4.0) {
          for (double y = h * 0.25; y < h * 0.75; y += 4.0) {
            canvas.drawCircle(Offset(x, y), 0.75, dot);
          }
        }
        break;
      case PaperSkin.kraftEnvelope:
        final redChevrons = Paint()..color = const Color(0xFFD32F2F).withOpacity(0.45)..strokeWidth = 1.8;
        final blueChevrons = Paint()..color = const Color(0xFF1976D2).withOpacity(0.45)..strokeWidth = 1.8;
        for (double x = w * 0.2; x < w * 0.8; x += 8) {
          canvas.drawLine(Offset(x, h * 0.18), Offset(x + 4, h * 0.18), redChevrons);
          canvas.drawLine(Offset(x + 4, h * 0.18), Offset(x + 8, h * 0.18), blueChevrons);
        }
        break;
      case PaperSkin.prideGradient:
        final waveShift = (_animTime * 0.6) % 1.0;
        final pridePaint = Paint()..shader = LinearGradient(begin: Alignment(-1.0 + waveShift, -1.0), end: Alignment(1.0 + waveShift, 1.0), colors: const [Color(0xFFFF1744), Color(0xFFFF9100), Color(0xFFFFEA00), Color(0xFF00E676), Color(0xFF2979FF), Color(0xFFAA00FF)]).createShader(Rect.fromLTWH(0, 0, w, h))..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), pridePaint);
        break;
      case PaperSkin.dragonScales:
        final scalePaint = Paint()..color = const Color(0xFF00E676).withOpacity(0.28)..style = PaintingStyle.stroke..strokeWidth = 0.9;
        for (double x = w * 0.25; x < w * 0.75; x += 7.0) {
          for (double y = h * 0.28; y < h * 0.75; y += 6.0) {
            canvas.drawPath(Path()..moveTo(x, y)..lineTo(x + 3.5, y + 4)..lineTo(x, y + 7)..lineTo(x - 3.5, y + 4)..close(), scalePaint);
          }
        }
        break;
      case PaperSkin.snowflake:
        final snowPaint = Paint()..color = Colors.white.withOpacity(0.55 * pulse)..strokeWidth = 0.8..style = PaintingStyle.stroke;
        final sc = Offset(w * 0.5, h * 0.5);
        for (int i = 0; i < 6; i++) {
          final ang = i * math.pi / 3 + _animTime * 0.2;
          canvas.drawLine(sc, Offset(sc.dx + math.cos(ang) * 9, sc.dy + math.sin(ang) * 9), snowPaint);
        }
        break;
      case PaperSkin.pumpkin:
        canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: 18, height: 14), Paint()..color = const Color(0xFFFFD54F).withOpacity(0.35 * pulse)..strokeWidth = 1.0..style = PaintingStyle.stroke);
        break;
      case PaperSkin.cherryBlossom:
        final petalPaint = Paint()..color = const Color(0xFFF48FB1).withOpacity(0.40 * pulse)..style = PaintingStyle.fill;
        for (int i = 0; i < 4; i++) {
          canvas.drawOval(Rect.fromCenter(center: Offset(w * (0.35 + i * 0.15), h * (0.35 + math.sin(_animTime * 3.0 + i) * 0.15)), width: 5, height: 3), petalPaint);
        }
        break;
      case PaperSkin.lavaLamp:
        final lavaA = Paint()..color = const Color(0xFFFF4081).withOpacity(0.35 + 0.1 * math.sin(_animTime * 3.0))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)..style = PaintingStyle.fill;
        final lavaB = Paint()..color = const Color(0xFF00E5FF).withOpacity(0.35 + 0.1 * math.cos(_animTime * 2.5))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(w * 0.45, h * 0.5 + math.sin(_animTime * 2.5) * 8), 9, lavaA);
        canvas.drawCircle(Offset(w * 0.65, h * 0.5 - math.sin(_animTime * 2.0) * 8), 11, lavaB);
        break;
      case PaperSkin.animatedHologram:
        final hue = (_animTime * 65.0) % 360.0;
        final color1 = HSLColor.fromAHSL(0.35, hue, 0.9, 0.6).toColor();
        final color2 = HSLColor.fromAHSL(0.35, (hue + 120) % 360.0, 0.9, 0.6).toColor();
        final color3 = HSLColor.fromAHSL(0.35, (hue + 240) % 360.0, 0.9, 0.6).toColor();
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color1, color2, color3, color1]).createShader(Rect.fromLTWH(0, 0, w, h))..style = PaintingStyle.fill);
        break;
      case PaperSkin.customCraft:
        canvas.drawCircle(Offset(w * 0.4, h * 0.4), 4, Paint()..color = Colors.white.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 0.9);
        canvas.drawCircle(Offset(w * 0.6, h * 0.6), 4, Paint()..color = Colors.white.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 0.9);
        break;
    }
  }

  // ── Active In-Flight Power-Up Overlays ──────────────────────────────────────

  void _drawPowerUpOverlays(Canvas canvas, double w, double h) {
    if (_ghostActive) _drawGhostShimmer(canvas, w, h);
    if (_magnetActive) _drawMagnetAura(canvas, w, h);
    if (_coinRushActive) _drawCoinRushGlow(canvas, w, h);
    if (_shieldActive) _drawShieldBubble(canvas, w, h);
    if (_doubleScoreActive) _drawDoubleScoreFlame(canvas, w, h);
    if (_windCallerActive) _drawWindCallerCompass(canvas, w, h);
    if (_decoyCloneActive) _drawDecoyClones(canvas, w, h);
    if (_blackHoleActive) _drawBlackHoleVortex(canvas, w, h);
    if (_turboDashActive) _drawTurboDashBlaze(canvas, w, h);

    // Stacking VFX: interlaced resonant aura if multiple active
    int activeCount = (_shieldActive ? 1 : 0) +
        (_ghostActive ? 1 : 0) +
        (_magnetActive ? 1 : 0) +
        (_coinRushActive ? 1 : 0) +
        (_doubleScoreActive ? 1 : 0) +
        (_turboDashActive ? 1 : 0);
    if (activeCount >= 2) {
      _drawStackingAura(canvas, w, h);
    }
  }

  // A. Shield: Geodesic Tessellation & Cracks
  void _drawShieldBubble(Canvas canvas, double w, double h) {
    final breathe = math.sin(_shieldPhase) * 0.15 + 0.85;
    final r = (w > h ? w : h) * 0.72 * breathe;
    final center = Offset(w / 2, h / 2);

    // Geodesic / faceted hexagonal origami dome facets
    final facetPaint = Paint()
      ..color = Color.fromRGBO(100, 181, 246, 0.16 * breathe)
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = Color.fromRGBO(144, 202, 249, 0.85 * breathe)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, r, facetPaint);
    canvas.drawCircle(center, r, rimPaint);

    // Facet lattice seams
    final seamPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      final a1 = i * math.pi / 3;
      final a2 = (i + 1) * math.pi / 3;
      final p1 = Offset(center.dx + math.cos(a1) * r, center.dy + math.sin(a1) * r);
      final p2 = Offset(center.dx + math.cos(a2) * r, center.dy + math.sin(a2) * r);
      canvas.drawLine(center, p1, seamPaint);
      canvas.drawLine(p1, p2, seamPaint);
    }

    // Ripple shockwave on hit
    if (_shieldHitRippleTimer > 0) {
      final rippleR = r + (1.0 - _shieldHitRippleTimer) * 18.0;
      final rippleAlpha = _shieldHitRippleTimer.clamp(0.0, 1.0);
      final ripplePaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.7 * rippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * rippleAlpha;
      canvas.drawCircle(center, rippleR, ripplePaint);
    }

    // Hairline crack texture when damaged or after near-miss
    if (_crumpleAmount > 0.01) {
      final crackPaint = Paint()
        ..color = Colors.white.withOpacity(_crumpleAmount * 0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(center.dx - 4, center.dy - r * 0.8), Offset(center.dx + 2, center.dy - r * 0.4), crackPaint);
      canvas.drawLine(Offset(center.dx + 2, center.dy - r * 0.4), Offset(center.dx - 3, center.dy), crackPaint);
      canvas.drawLine(Offset(center.dx - 3, center.dy), Offset(center.dx + 6, center.dy + r * 0.4), crackPaint);
    }
  }

  // B. Magnet: Orbiting Iron Filing Particles & Flux Lines
  void _drawMagnetAura(Canvas canvas, double w, double h) {
    final center = Offset(w / 2, h / 2);
    final r = w * 0.75 + 4.0;

    // Magnetic purple aura
    final glowPaint = Paint()
      ..color = const Color(0x55AB47BC)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, r + 4, glowPaint);

    // Magnetic flux field arcs (36 deg/s rotating field)
    final fluxPaint = Paint()
      ..color = Color.fromRGBO(212, 143, 229, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), _magnetAngle, math.pi * 0.8, false, fluxPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), _magnetAngle + math.pi, math.pi * 0.8, false, fluxPaint);

    // Orbiting iron filing particles
    final filing = Paint()..color = const Color(0xFFE1BEE7)..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final a = _magnetAngle + i * (math.pi / 3);
      final px = center.dx + math.cos(a) * (r + 2);
      final py = center.dy + math.sin(a) * (r * 0.6);
      canvas.drawCircle(Offset(px, py), 1.5, filing);
    }
  }

  // C. Ghost: 2-3 Phasing After-Images & Cyan Shimmer from Trail History
  void _drawGhostShimmer(Canvas canvas, double w, double h) {
    final flicker = 0.4 + 0.3 * math.sin(_ghostPhase);
    final outlinePaint = Paint()
      ..color = Color.fromRGBO(0, 229, 255, flicker)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h / 2), width: w + 12, height: h + 12),
        const Radius.circular(8),
      ),
      outlinePaint,
    );
  }

  void _drawGhostAfterImages(Canvas canvas, double w, double h, double wingFold, Color planeColor) {
    final trailPositions = _trail.recentPositions;
    final count = trailPositions.length;
    if (count < 3) return;

    final parentPos = position;
    final halfW = w / 2;
    final halfH = h / 2;

    final ghostPaint = Paint()
      ..color = const Color(0x3580DEEA)
      ..style = PaintingStyle.fill;

    final indices = [count - 3, count - 6, count - 9];
    for (int k = 0; k < indices.length; k++) {
      final idx = indices[k];
      if (idx < 0 || idx >= count) continue;
      final pastPos = trailPositions[idx];
      final dx = pastPos.x - parentPos.x;
      final dy = pastPos.y - parentPos.y;
      final opacity = 0.18 / (k + 1);

      canvas.save();
      canvas.translate(halfW + dx, halfH + dy);
      canvas.rotate(-math.pi / 2);
      canvas.translate(-halfW, -halfH);
      _drawPlaneShape(canvas, ghostPaint, w, h, wingFold, isShadow: false, planeColor: planeColor, opacity: opacity);
      canvas.restore();
    }
  }

  // D. Slow-Mo Stretched After-Image
  void _drawSlowMoAfterImage(Canvas canvas, double w, double h, double wingFold, Color planeColor) {
    final slowPaint = Paint()
      ..color = const Color(0x2800E5FF)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(0, 6.0);
    _drawPlaneShape(canvas, slowPaint, w, h, wingFold, isShadow: false, planeColor: planeColor, opacity: 0.25);
    canvas.restore();
  }

  // E. Coin Rush: Saturn Ring of Orbiting Gold Coins & Wingtip Emitters
  void _drawCoinRushGlow(Canvas canvas, double w, double h) {
    final center = Offset(w / 2, h / 2);
    final rx = w * 0.85;
    final ry = h * 0.45;

    // Golden halo
    final glowPaint = Paint()
      ..color = const Color(0x66FFD700)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, w * 0.75, glowPaint);

    // Saturn Ring of miniature gold coins
    final coinPaint = Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.fill;
    final coinRim = Paint()..color = const Color(0xFFFFA000)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    for (int i = 0; i < 5; i++) {
      final a = _coinRushPhase + i * (2 * math.pi / 5);
      final px = center.dx + math.cos(a) * rx;
      final py = center.dy + math.sin(a) * ry;
      canvas.drawCircle(Offset(px, py), 2.8, coinPaint);
      canvas.drawCircle(Offset(px, py), 2.8, coinRim);
    }

    // Wingtip gold dust sparkles
    final spark = Paint()..color = const Color(0xFFFFF9C4)..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final sy = h / 2 + 10 + (i * 7);
      canvas.drawCircle(Offset(w * 0.15 + math.sin(_animTime * 15.0 + i) * 2, sy), 1.2, spark);
      canvas.drawCircle(Offset(w * 0.85 + math.sin(_animTime * 15.0 + i + 1) * 2, sy), 1.2, spark);
    }
  }

  // F. Stacking VFX: Interlaced Resonant Vortex
  void _drawStackingAura(Canvas canvas, double w, double h) {
    final center = Offset(w / 2, h / 2);
    final r1 = w * 0.82;
    final r2 = w * 0.72;

    final p1 = Paint()
      ..color = const Color(0x66AB47BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final p2 = Paint()
      ..color = const Color(0x66FFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawCircle(center, r1, p1);
    canvas.drawCircle(center, r2, p2);
  }

  // G. Double Score: Red-Orange Jet Exhaust Flames
  void _drawDoubleScoreFlame(Canvas canvas, double w, double h) {
    final flameFlicker = math.sin(_doubleScorePhase) * 0.3 + 0.7;
    final flameLen = 22.0 * flameFlicker;
    final flamePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF3D00), Color(0xFFFF9100), Color(0x00FFEA00)],
      ).createShader(Rect.fromLTWH(w / 2 - 4, h / 2 + 8, 8, flameLen))
      ..style = PaintingStyle.fill;

    final flamePath = Path()
      ..moveTo(w / 2 - 4, h / 2 + 8)
      ..lineTo(w / 2, h / 2 + 8 + flameLen)
      ..lineTo(w / 2 + 4, h / 2 + 8)
      ..close();
    canvas.drawPath(flamePath, flamePaint);
  }

  // H. Wind Caller: 8-Point Compass Rose
  void _drawWindCallerCompass(Canvas canvas, double w, double h) {
    final rose = Paint()
      ..color = const Color(0xAA00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final center = Offset(w / 2, h / 2 - 16);
    canvas.drawCircle(center, 7, rose);
    canvas.drawLine(Offset(center.dx, center.dy - 11), Offset(center.dx, center.dy + 11), rose);
    canvas.drawLine(Offset(center.dx - 11, center.dy), Offset(center.dx + 11, center.dy), rose);
  }

  // I. Decoy Clones: 2 Flanking Ghost Paper Planes
  void _drawDecoyClones(Canvas canvas, double w, double h) {
    final decoyPaint = Paint()
      ..color = const Color(0x447986CB)
      ..style = PaintingStyle.fill;
    final decoyRim = Paint()
      ..color = const Color(0x88C5CAE9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final dx in [-36.0, 36.0]) {
      final cx = w / 2 + dx;
      final cy = h / 2 + 4;
      final path = Path()
        ..moveTo(cx, cy - 14)
        ..lineTo(cx - 12, cy + 10)
        ..lineTo(cx, cy + 5)
        ..lineTo(cx + 12, cy + 10)
        ..close();
      canvas.drawPath(path, decoyPaint);
      canvas.drawPath(path, decoyRim);
    }
  }

  // J. Black Hole: Cosmic Accretion Vortex
  void _drawBlackHoleVortex(Canvas canvas, double w, double h) {
    final center = Offset(w / 2, h / 2);
    final vortex = Paint()
      ..shader = SweepGradient(
        colors: const [Color(0xFF311B92), Color(0xFF7C4DFF), Color(0xFF00E5FF), Color(0xFF311B92)],
        transform: GradientRotation(_blackHoleAngle),
      ).createShader(Rect.fromCircle(center: center, radius: 28))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, 24, vortex);
    canvas.drawCircle(center, 12, Paint()..color = Colors.black..style = PaintingStyle.fill);
  }

  // K. Turbo Dash: Blazing Hypersonic Plasma Barrier Cone
  void _drawTurboDashBlaze(Canvas canvas, double w, double h) {
    final blaze = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xCCFFFFFF), Color(0xAAFF3D00), Color(0x00FF9100)],
      ).createShader(Rect.fromLTWH(w / 2 - 18, h / 2 - 28, 36, 40))
      ..style = PaintingStyle.fill;

    final cone = Path()
      ..moveTo(w / 2, h / 2 - 28)
      ..lineTo(w / 2 - 20, h / 2 + 10)
      ..lineTo(w / 2 + 20, h / 2 + 10)
      ..close();
    canvas.drawPath(cone, blaze);
  }

  // ── Snap Charge Ring (Double Ring Concept & Per-Plane Styles) ──────────────

  void _drawSnapChargeRing(Canvas canvas, double w, double h) {
    if (game.phase != GamePhase.playing && game.phase != GamePhase.paused) {
      return;
    }

    final input = game.inputManager;
    final maxC = (planeType == PlaneType.stuntFold && planeLevel >= 3) ? 3 : GameConfig.snapMaxCharges;
    final charges = input.snapCharges;
    final progress = input.snapRechargeFraction;
    final center = Offset(w / 2, h / 2);
    final outerRadius = GameConfig.snapRingRadius;
    final innerRadius = outerRadius * 0.72;
    final stroke = GameConfig.snapRingStrokeWidth;

    // ── Charge States: 0 = Red slow pulse, 1 = Amber breathing, Max = Gold shimmer
    final Color stateColor;
    if (charges == 0) {
      final redPulse = math.sin(_animTime * 4.0) * 0.25 + 0.75;
      stateColor = Color.fromRGBO(255, 82, 82, redPulse);
    } else if (charges < maxC) {
      final amberPulse = math.sin(_animTime * 3.0) * 0.2 + 0.8;
      stateColor = Color.fromRGBO(255, 160, 0, amberPulse);
    } else {
      final goldShimmer = math.sin(_animTime * 6.0) * 0.15 + 0.85;
      stateColor = Color.fromRGBO(255, 215, 0, goldShimmer);
    }

    // ── 1. Inner Ring: Defensive / Ability Buffer (Shield / Crane / Decoys) ───
    final shieldCharges = _shieldActive ? 1 : 0;
    final craneCharges = game.craneChargesRemaining;
    final decoyCharges = game.decoyCloneCharges;
    final innerActive = shieldCharges > 0 || craneCharges > 0 || decoyCharges > 0;

    if (innerActive) {
      final innerAngle = _magnetActive ? _magnetAngle : (_slowMoActive ? _animTime * 0.5 : _animTime);
      final Color innerColor = shieldCharges > 0
          ? const Color(0xFF64B5F6) // glowing blue
          : (craneCharges > 0 ? const Color(0xFF81C784) : const Color(0xFF7986CB));

      final innerPaint = Paint()
        ..color = innerColor.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(innerAngle);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: innerRadius),
        0,
        math.pi * 1.6,
        false,
        innerPaint,
      );
      canvas.restore();
    }

    // ── 2. Outer Ring: Snap Boost Charges with Per-Plane Style ───────────────
    final bgPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, outerRadius, bgPaint);

    const gap = GameConfig.snapRingGapRadians;
    final totalArc = (2 * math.pi - gap * maxC) / maxC;

    for (int i = 0; i < maxC; i++) {
      final start = -math.pi / 2 + i * (totalArc + gap);
      double sweep = totalArc;
      final bool isFilled = i < charges;
      Paint segPaint;

      if (isFilled) {
        segPaint = Paint()
          ..color = stateColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
      } else if (i == charges && charges < maxC) {
        final fillFraction = progress.clamp(0.0, 1.0);
        if (fillFraction <= 0.01) continue;
        sweep = totalArc * fillFraction;
        segPaint = Paint()
          ..color = stateColor.withOpacity(0.5 + 0.4 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
      } else {
        segPaint = Paint()
          ..color = const Color(0x33FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.8
          ..strokeCap = StrokeCap.round;
      }

      // Per-plane styling
      if (_ghostActive) {
        segPaint.strokeWidth = 1.4;
        segPaint.color = segPaint.color.withOpacity(0.45);
      }

      _drawStyledRingSegment(canvas, center, outerRadius, start, sweep, segPaint);
    }

    // Gold Sparkle Particles when Fully Charged
    if (charges >= maxC) {
      final spark = Paint()..color = const Color(0xFFFFF9C4)..style = PaintingStyle.fill;
      for (int i = 0; i < 3; i++) {
        final a = _animTime * 4.0 + i * (2 * math.pi / 3);
        final sx = center.dx + math.cos(a) * (outerRadius + 3);
        final sy = center.dy + math.sin(a) * (outerRadius + 3);
        canvas.drawCircle(Offset(sx, sy), 1.2, spark);
      }
    }

    // ── 3. Exploding Paper-Confetti Shards on Boost Burst ────────────────────
    if (_snapFlashTimer > 0) {
      final f = (_snapFlashTimer / 0.22).clamp(0.0, 1.0);
      final expand = (1.0 - f) * 28.0;

      final flashPaint = Paint()
        ..color = stateColor.withOpacity(0.6 * f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 3.0 * f
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, outerRadius + expand, flashPaint);

      // Radiating origami confetti shards
      final shardPaint = Paint()
        ..color = Color.fromRGBO(255, 215, 0, 0.85 * f)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final px = center.dx + math.cos(a) * (outerRadius + expand);
        final py = center.dy + math.sin(a) * (outerRadius + expand);
        final shard = Path()
          ..moveTo(px, py - 3 * f)
          ..lineTo(px + 4 * f, py)
          ..lineTo(px, py + 3 * f)
          ..lineTo(px - 4 * f, py)
          ..close();
        canvas.drawPath(shard, shardPaint);
      }
    }
  }

  void _drawStyledRingSegment(
    Canvas canvas,
    Offset center,
    double radius,
    double start,
    double sweep,
    Paint paint,
  ) {
    switch (planeType) {
      case PlaneType.glider:
        // Feathered / dashed aerodynamic arcs
        const dashes = 4;
        final dashSweep = sweep / (dashes * 1.5);
        for (int d = 0; d < dashes; d++) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            start + d * dashSweep * 1.5,
            dashSweep,
            false,
            paint,
          );
        }
        break;

      case PlaneType.stuntFold:
        // Angular zig-zag lightning styling
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint..strokeWidth = paint.strokeWidth * 1.2,
        );
        break;

      case PlaneType.crane:
        // Origami mountain/valley fold line with diamond node
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
        final nodeA = start + sweep;
        final nx = center.dx + math.cos(nodeA) * radius;
        final ny = center.dy + math.sin(nodeA) * radius;
        canvas.drawCircle(Offset(nx, ny), 2.2, Paint()..color = paint.color..style = PaintingStyle.fill);
        break;

      case PlaneType.stealthJet:
        // Tactical HUD hexagon brackets
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint..strokeCap = StrokeCap.square,
        );
        break;

      default:
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
        break;
    }
  }

  void _triggerSnapFlash() {
    _snapFlashTimer = 0.22;
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_isAlive) return;
    if (game.phase != GamePhase.playing) return;

    _animTime += dt;

    final input = game.inputManager;
    final wind = game.windSystem;
    final sensitivity = game.inputManager.currentSensitivity;
    final fallMult = planeType.fallSpeedForLevel(planeLevel);

    final isHolding = input.isHolding;
    final pressEdge = isHolding && !_wasHolding;
    final releaseEdge = !isHolding && _wasHolding;

    // Reflect active power-ups so render() can draw their visuals.
    final session = gameRef.ref.read(gameSessionProvider);
    _shieldActive = session.shieldActive;
    _ghostActive = session.activePowerUps.contains(PowerUpType.ghost);
    _magnetActive = session.activePowerUps.contains(PowerUpType.magnet);
    _coinRushActive = session.activePowerUps.contains(PowerUpType.coinRush);
    _slowMoActive = session.activePowerUps.contains(PowerUpType.slowMo);
    _doubleScoreActive = session.activePowerUps.contains(PowerUpType.doubleScore);
    _shrinkActive = session.activePowerUps.contains(PowerUpType.shrink);
    _windCallerActive = session.activePowerUps.contains(PowerUpType.windCaller);
    _decoyCloneActive = session.activePowerUps.contains(PowerUpType.decoyClone) || game.decoyCloneCharges > 0;
    _blackHoleActive = session.activePowerUps.contains(PowerUpType.blackHole);
    _turboDashActive = session.activePowerUps.contains(PowerUpType.turboDash);

    // Update distinct pulse channels
    _shieldPhase += dt * (1.2 * 2 * math.pi);
    _ghostPhase += dt * (8.0 * 2 * math.pi);
    _magnetAngle += dt * (36.0 * math.pi / 180.0);
    _coinRushPhase += dt * (3.0 * 2 * math.pi);
    _slowMoPhase += dt * (1.0 * 2 * math.pi);
    _doubleScorePhase += dt * (12.0 * 2 * math.pi);
    _turboDashPhase += dt * (20.0 * 2 * math.pi);
    _blackHoleAngle += dt * (180.0 * math.pi / 180.0);

    if (_shieldHitRippleTimer > 0) {
      _shieldHitRippleTimer = (_shieldHitRippleTimer - dt * 2.5).clamp(0.0, 1.0);
    }
    if (_snapFlashTimer > 0) {
      _snapFlashTimer = (_snapFlashTimer - dt).clamp(0.0, 10.0);
    }
    if (_ceilingStallTimer > 0) {
      _ceilingStallTimer = (_ceilingStallTimer - dt).clamp(0.0, 10.0);
    }
    if (_crumpleAmount > 0) {
      _crumpleAmount = (_crumpleAmount - dt / 3.5).clamp(0.0, 1.0);
    }

    // Shrink hitbox update
    final baseScale = planeType.hitboxScaleForLevel(planeLevel) ??
        planeType.hitboxScaleOverride ??
        GameConfig.planeHitboxScale;
    final currentScale = _shrinkActive ? GameConfig.shrinkHitboxScale : baseScale;
    final hbSize = size * currentScale;
    _hitbox.size = hbSize;
    _hitbox.position = (size - hbSize) / 2;

    // ── Vertical Physics ─────────────────────────────────────────────────────

    if (pressEdge) {
      _glideArcActive = false;
      _oscillationStrength = 0.0;
      _playHoldKickEffect();
    }

    if (isHolding) {
      _velocityY = MathUtils.lerp(
        _velocityY,
        GameConfig.liftCruiseSpeed,
        (GameConfig.liftKickDecayRate * dt).clamp(0.0, 1.0),
      );
      _oscillationStrength =
          (_oscillationStrength - 3.0 * dt).clamp(0.0, 1.0);
    } else {
      if (releaseEdge) {
        if (_velocityY < 0) {
          _glideArcActive = true;
        } else {
          _glideArcActive = false;
        }
        _oscillationPhase = 0.0;
        _oscillationStrength = 0.0;
      }

      final glideScale = (planeType == PlaneType.glider || planeType == PlaneType.albatross)
          ? GameConfig.glideGravityScale * (planeLevel >= 3 ? 0.70 : (planeLevel == 2 ? 0.75 : 0.80))
          : GameConfig.glideGravityScale;

      final diveRecoveryScale = (planeType == PlaneType.stealthJet && _velocityY > 60)
          ? (planeLevel >= 3 ? 0.76 : (planeLevel == 2 ? 0.82 : 0.88))
          : (planeType == PlaneType.rocket && _velocityY > 60 ? 0.80 : 1.0);

      if (_glideArcActive) {
        _velocityY += GameConfig.gravity *
            glideScale *
            fallMult *
            wind.profile.gravity *
            diveRecoveryScale *
            dt;
        _oscillationStrength = (_oscillationStrength +
                GameConfig.oscillationFadeInRate * dt)
            .clamp(0.0, 1.0);
        if (_velocityY >= 0) {
          _glideArcActive = false;
        }
      } else {
        final fullScale = GameConfig.fullGravityScale * diveRecoveryScale;
        _velocityY += GameConfig.gravity *
            fullScale *
            fallMult *
            wind.profile.gravity *
            dt;
        _oscillationStrength = (_oscillationStrength +
                GameConfig.oscillationFadeInRate * dt)
            .clamp(0.0, 1.0);
      }

      _oscillationPhase += GameConfig.oscillationFrequency * 2.0 * math.pi * dt;
      final oscContrib = math.sin(_oscillationPhase) *
          GameConfig.oscillationAmplitude *
          _oscillationStrength;
      _velocityY += oscContrib * dt;
    }

    // Paper-snap burst
    if (input.consumeSnap()) {
      final snapMult = (planeType == PlaneType.dart && planeLevel >= 3)
          ? 1.15
          : (planeType == PlaneType.rocket && planeLevel >= 3 ? 1.20 : 1.0);
      _velocityY = GameConfig.snapBurstVelocity * snapMult;
      _glideArcActive = false;
      _triggerSnapFlash();
      _playSnapBurstEffect();
    }

    // Turbo Dash upward glide assist
    if (_turboDashActive) {
      _velocityY = MathUtils.lerp(_velocityY, -60.0, dt * 5.0);
    }

    // Thermal lift bonus from wind lane
    final normX = position.x / GameConfig.designWidth;
    final laneIndex = wind.laneForNormX(normX);
    final laneWind = wind.windAt(laneIndex);
    final inThermal = laneWind.type == WindType.thermal;
    _inThermal = inThermal;

    _thermalBreathFactor = MathUtils.lerp(
        _thermalBreathFactor, inThermal ? 1.0 : 0.0, dt * 3.5);

    if (inThermal) {
      double lift = laneWind.liftBonus;
      if (planeType == PlaneType.glider) {
        final gMult = planeLevel >= 3 ? 1.50 : (planeLevel == 2 ? 1.35 : 1.20);
        lift *= gMult;
      } else if (planeType == PlaneType.butterfly) {
        final bMult = planeLevel >= 3 ? 1.65 : (planeLevel == 2 ? 1.50 : 1.40);
        lift *= bMult;
      } else if (planeType == PlaneType.crane && planeLevel >= 3) {
        lift *= 1.15;
      }
      _velocityY -= lift * dt;
    }

    _velocityY = _velocityY.clamp(
      GameConfig.snapBurstVelocity * 1.2,
      GameConfig.maxFallSpeed * fallMult,
    );

    // ── Horizontal Physics ────────────────────────────────────────────────────

    final controlMult = wind.isInTurbulence(normX)
        ? (1.0 - GameConfig.turbulenceControlReduction)
        : 1.0;
    double biomeControl = wind.profile.control;
    if (planeType == PlaneType.stealthJet) {
      final wBonus = planeLevel >= 3 ? 1.20 : (planeLevel == 2 ? 1.15 : 1.08);
      biomeControl *= wBonus;
    }

    final turnMult = planeType.turnSpeedForLevel(planeLevel);
    final baseSpeed = input.currentScheme == ControlScheme.joystick
        ? GameConfig.joystickMaxSteerSpeed
        : GameConfig.maxTiltSpeed;
    var targetVX = input.horizontalInput *
        baseSpeed *
        turnMult *
        controlMult *
        biomeControl *
        sensitivity;

    if (planeType == PlaneType.butterfly) {
      final swayAmp = planeLevel >= 2 ? 32.0 : 25.0;
      final autoSway = math.sin(_animTime * 2.6) * swayAmp;
      targetVX += autoSway;
    }

    // Steering intent and crosswind are composed before the input layer applies
    // the airframe's dynamic wing-loading response. This replaces the old
    // fixed per-frame lerp: Butterfly/Albatross folds track corrections almost
    // instantly while Bomber/Rocket folds have to carry their bank through a
    // reversal. The same state machine is used by tilt, touch zones, and stick.
    _velocityX = input.resolveTurnMomentum(
      planeType: planeType,
      desiredVelocity: targetVX + laneWind.lateralForce,
      hasSteeringInput:
          input.horizontalInput.abs() > GameConfig.turnMomentumInputDeadZone,
      dt: dt,
    );

    // ── Integrate Position ────────────────────────────────────────────────────

    final minX = GameConfig.horizontalEdgeMargin;
    final maxX = GameConfig.designWidth - GameConfig.horizontalEdgeMargin;
    final proposedX = position.x + _velocityX * dt;
    position.x = proposedX.clamp(minX, maxX).toDouble();
    position.y += _velocityY * dt;

    // Keep the input model in sync with physical bounds. Without this, a heavy
    // plane pushed into an edge by a gust would keep invisible outward momentum
    // and feel sticky when the pilot begins correcting back into the play area.
    if (proposedX <= minX && _velocityX < 0) {
      _velocityX = 0;
      input.blockTurnMomentumAtEdge(left: true);
    } else if (proposedX >= maxX && _velocityX > 0) {
      _velocityX = 0;
      input.blockTurnMomentumAtEdge(right: true);
    }

    // ── Soft Altitude Ceiling ─────────────────────────────────────────────────
    _handleCeiling(dt);

    // ── Fail State ────────────────────────────────────────────────────────────
    if (position.y > GameConfig.designHeight + size.y) {
      if (game.mode == GameMode.zen) {
        position.y = GameConfig.zenSoftFloorY;
        _velocityY = GameConfig.zenSoftFloorBounce;
        _glideArcActive = false;
      } else {
        game.onPlaneCrash();
      }
      return;
    }

    _updateRotation(dt);
    _wingFold = MathUtils.lerp(_wingFold, isHolding ? 1.0 : 0.0, 0.10);
    _wasHolding = isHolding;
  }

  void _updateRotation(double dt) {
    final double bankFactor;
    final double lerpSpeed;

    if (planeType == PlaneType.glider || planeType == PlaneType.albatross) {
      bankFactor = 0.0007;
      lerpSpeed = 5.0;
    } else if (planeType == PlaneType.butterfly) {
      bankFactor = 0.0008;
      lerpSpeed = 6.0;
    } else if (planeType == PlaneType.interceptor || planeType == PlaneType.ninjaStar) {
      bankFactor = 0.0014;
      lerpSpeed = 12.0;
    } else {
      bankFactor = 0.0012;
      lerpSpeed = 9.5;
    }

    const maxBankRad = 12.0 * math.pi / 180.0;
    final targetAngle = (_velocityX * bankFactor).clamp(-maxBankRad, maxBankRad);

    angle = MathUtils.lerp(angle, targetAngle, (lerpSpeed * dt).clamp(0.0, 1.0));
  }

  void onNearMiss(NearMissTier tier) {
    final addCrumple = switch (tier) {
      NearMissTier.deathDefying => 1.0,
      NearMissTier.hairThin => 0.75,
      NearMissTier.closeShave => 0.45,
    };
    _crumpleAmount = math.min(1.0, _crumpleAmount + addCrumple);
  }

  void _handleCeiling(double dt) {
    if (position.y >= GameConfig.ceilingSoftY) {
      _ceilingWasInSoftZone = false;
      return;
    }

    if (_velocityY < 0) {
      if (position.y <= GameConfig.ceilingY) {
        position.y = GameConfig.ceilingY;
        if (!_ceilingWasInSoftZone) {
          _velocityY = GameConfig.ceilingStallPush;
        } else {
          _velocityY = (_velocityY * 0.15 + GameConfig.ceilingStallPush * 0.6)
              .clamp(-20.0, GameConfig.ceilingStallPush);
        }
        _ceilingStallTimer = GameConfig.ceilingDipDuration;
        _ceilingWasInSoftZone = true;
        _oscillationStrength *= 0.4;
        _playCeilingStallEffect();
      } else {
        final t = (GameConfig.ceilingSoftY - position.y) /
            (GameConfig.ceilingSoftY - GameConfig.ceilingY);
        final damping = GameConfig.ceilingResistanceDamping * t;
        _velocityY = MathUtils.lerp(
          _velocityY,
          GameConfig.ceilingStallPush * 0.12 * t,
          (damping * dt * 60).clamp(0.0, 0.85),
        );
        position.y += GameConfig.ceilingStallPush * t * dt * 0.18;
        position.y = position.y.clamp(GameConfig.ceilingY, double.infinity);
        if (t > 0.7 && _ceilingStallTimer <= 0) {
          _ceilingStallTimer = GameConfig.ceilingDipDuration * 0.35;
        }
      }
    } else {
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
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2.all(1.18),
        EffectController(duration: 0.07, reverseDuration: 0.07),
      ),
    );
  }

  void _playHoldKickEffect() {
    children.whereType<ScaleEffect>().toList().forEach(remove);
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

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
  }

  void reset() {
    _isAlive = true;
    _velocityX = 0;
    _velocityY = 0;
    _wingFold = 0;
    _wasHolding = false;
    _glideArcActive = false;
    _oscillationPhase = 0;
    _oscillationStrength = 0;
    _ceilingStallTimer = 0.0;
    _ceilingWasInSoftZone = false;
    _snapFlashTimer = 0.0;
    _inThermal = false;
    _thermalBreathFactor = 0.0;
    _crumpleAmount = 0.0;
    _shieldActive = false;
    _ghostActive = false;
    _magnetActive = false;
    _coinRushActive = false;
    _slowMoActive = false;
    _doubleScoreActive = false;
    _shrinkActive = false;
    _windCallerActive = false;
    _decoyCloneActive = false;
    _blackHoleActive = false;
    _turboDashActive = false;
    _shieldHitRippleTimer = 0.0;
    angle = 0;
    _animTime = 0.0;
    position = Vector2(
      GameConfig.designWidth * GameConfig.planeStartX,
      GameConfig.designHeight * GameConfig.planeStartY,
    );

    _trail.clear();
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
    _crumpleAmount = 0.0;
    _thermalBreathFactor = 0.0;
    _shieldHitRippleTimer = 0.0;
    angle = 0;
    position.y = GameConfig.designHeight * 0.5;

    _trail.clear();

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
    _shieldHitRippleTimer = 1.0;
    add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 0.08, reverseDuration: 0.08),
      ),
    );
  }

  void playGhostPhaseAnimation() {
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2.all(1.22),
        EffectController(duration: 0.06, reverseDuration: 0.06),
      ),
    );
  }

  void applyZenBounce({required double pushX, required double pushY}) {
    _velocityX += pushX;
    _velocityY += pushY;
    _glideArcActive = false;
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2.all(1.16),
        EffectController(duration: 0.09, reverseDuration: 0.14),
      ),
    );
  }

  void playBranchBrushAnimation() {
    children.whereType<ScaleEffect>().toList().forEach(remove);
    add(
      ScaleEffect.by(
        Vector2.all(1.18),
        EffectController(duration: 0.07, reverseDuration: 0.12),
      ),
    );
    add(
      RotateEffect.by(
        0.45,
        EffectController(duration: 0.08, reverseDuration: 0.08),
      ),
    );
  }

  Vector2 get worldPosition => absolutePosition;

  double get horizontalVelocity => _velocityX;

  double get verticalVelocity => _velocityY;

  Rect get worldAabbRect {
    final baseScale = planeType.hitboxScaleForLevel(planeLevel) ??
        planeType.hitboxScaleOverride ??
        GameConfig.planeHitboxScale;
    final scale = _shrinkActive ? GameConfig.shrinkHitboxScale : baseScale;
    final hbSize = size * scale;
    return Rect.fromCenter(
      center: position.toOffset(),
      width: hbSize.x,
      height: hbSize.y,
    );
  }
}
