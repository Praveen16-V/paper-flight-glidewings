import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
import '../../paper_flight_game.dart';
import '../plane_component.dart';

/// Base class for all obstacle types.
///
/// Each obstacle:
///  - Spawns just above the top of the viewport.
///  - Translates downward at [game.scrollSpeed] × dt each frame.
///  - Detects collision with [PlaneComponent] and calls [game.onPlaneCrash].
///  - Detects near-miss (plane passes within [GameConfig.nearMissDistance] px)
///    and awards bonus via [ScoringSystem].
///  - Displays an off-screen hazard telegraph beacon at the top edge of the
///    viewport when descending from above, giving players fair reaction time.
///  - Calls [onRecycle] when it exits the bottom of the viewport so the
///    spawner can return it to the pool.
abstract class ObstacleComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  ObstacleComponent({required this.type}) : super(anchor: Anchor.topCenter);

  final ObstacleType type;

  bool _active = false;
  bool get isActive => _active;
  bool _nearMissAwarded = false;
  void Function(ObstacleComponent)? onRecycle;

  /// Elapsed time since this obstacle was activated.
  double animTime = 0.0;

  /// Whether to display an off-screen hazard telegraph indicator when above viewport.
  bool get hasTelegraph => true;

  /// Color used for the off-screen hazard warning indicator.
  Color get telegraphColor => const Color(0xFFFF9800);

  // ── Activation ─────────────────────────────────────────────────────────────

  /// Prepare this obstacle for a new spawn. Called by the spawner.
  void activate({
    required double spawnX,
    required double scrollSpeed,
    void Function(ObstacleComponent)? recycleCallback,
  }) {
    position = Vector2(spawnX, GameConfig.obstacleSpawnY);
    _active = true;
    _nearMissAwarded = false;
    animTime = 0.0;
    onRecycle = recycleCallback;
    onActivate(scrollSpeed);
  }

  void deactivate() {
    _active = false;
    onRecycle = null;
    _nearMissAwarded = false;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  /// Override in subclasses to set dynamic-specific state.
  void onActivate(double scrollSpeed) {}

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_active) return;

    animTime += dt;

    // Scroll downward with the world.
    position.y += game.scrollSpeed * dt;

    // Subclass-specific movement & internal animation updates.
    updateObstacle(dt);

    // Near-miss detection.
    _checkNearMiss();

    // Recycle when below the viewport.
    if (position.y > GameConfig.obstacleRecycleY) {
      _active = false;
      onRecycle?.call(this);
    }

    super.update(dt);
  }

  /// Override for dynamic obstacles that move beyond simple vertical scroll.
  void updateObstacle(double dt) {}

  // ── Collision ──────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (!_active) return;
    if (other is PlaneComponent) {
      game.onPlaneCrash();
    }
  }

  // ── Near-Miss ──────────────────────────────────────────────────────────────

  void _checkNearMiss() {
    if (_nearMissAwarded) return;
    final plane = game.plane;
    final dist = MathUtils.distance(
      plane.position.x, plane.position.y,
      position.x, position.y,
    );
    // Near-miss: plane passed very close but collision wasn't triggered.
    if (dist < GameConfig.nearMissDistance + size.x * 0.5 &&
        dist > GameConfig.nearMissDistance * 0.25) {
      _nearMissAwarded = true;
      game.scoringSystem.onNearMiss(position: plane.position);
    }
  }

  // ── Off-screen Telegraph Rendering ─────────────────────────────────────────

  /// Renders a hazard warning chevron at the top edge of the screen when the
  /// obstacle is descending from above (between -240px and -10px).
  void renderTelegraph(Canvas canvas) {
    if (!hasTelegraph || !_active || position.y >= 0 || position.y < -260) {
      return;
    }

    // Distance factor (0 at -260, 1 at 0)
    final progress = (1.0 - (position.y.abs() / 260.0)).clamp(0.0, 1.0);
    final pulse = (math.sin(animTime * 14.0) * 0.5 + 0.5);
    final alpha = (progress * (0.65 + 0.35 * pulse)).clamp(0.0, 1.0);

    final warningPaint = Paint()
      ..color = telegraphColor.withOpacity(alpha)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = telegraphColor.withOpacity(alpha * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Target X clamped to screen margins
    final beaconX = position.x.clamp(32.0, GameConfig.designWidth - 32.0);
    const beaconY = 18.0;

    canvas.save();
    canvas.translate(beaconX, beaconY);

    // Outer glow
    canvas.drawCircle(Offset.zero, 14, glowPaint);

    // Diamond badge background
    final badgePath = Path()
      ..moveTo(0, -12)
      ..lineTo(11, 0)
      ..lineTo(0, 12)
      ..lineTo(-11, 0)
      ..close();
    canvas.drawPath(badgePath, warningPaint);

    // Dark exclamation mark inside
    final innerPaint = Paint()
      ..color = const Color(0xFF1A1A24)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.5, -7, 3, 7.5),
        const Radius.circular(1),
      ),
      innerPaint,
    );
    canvas.drawCircle(const Offset(0, 3.5), 1.6, innerPaint);

    // Downward pulsing arrow chevron below badge
    final chevronY = 15.0 + pulse * 3.0;
    final chevronPath = Path()
      ..moveTo(-6, chevronY)
      ..lineTo(0, chevronY + 6)
      ..lineTo(6, chevronY)
      ..lineTo(4.5, chevronY)
      ..lineTo(0, chevronY + 4.5)
      ..lineTo(-4.5, chevronY)
      ..close();
    canvas.drawPath(chevronPath, warningPaint);

    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. PowerLineObstacle — Sagging Catenary Cables, Pylon Towers & Electric Sparks
// ─────────────────────────────────────────────────────────────────────────────

/// High-voltage power line spanning the screen with realistic sagging catenary
/// cables, steel lattice pylon towers, animated electrical discharge sparks, and
/// wind-fluttering aviation marker flags.
class PowerLineObstacle extends ObstacleComponent {
  PowerLineObstacle() : super(type: ObstacleType.powerLine);

  double _gapX = 0;
  double _gapWidth = 95;
  double _sparkTimer = 0;
  double _sparkX = 0;
  double _sparkAlpha = 0;
  bool _sparkOnLeft = true;

  @override
  Color get telegraphColor => const Color(0xFFFFD54F);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 40);
    _gapWidth = MathUtils.randomRange(92, 125);
    _gapX = MathUtils.randomRange(
      GameConfig.horizontalEdgeMargin + 35,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - _gapWidth - 35,
    );
    _sparkTimer = MathUtils.randomRange(0.5, 2.0);
    _sparkAlpha = 0;
    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    // Left segment hitbox
    add(RectangleHitbox(
      size: Vector2(_gapX, 22),
      position: Vector2(0, 8),
    ));
    // Right segment hitbox
    final rightStart = _gapX + _gapWidth;
    add(RectangleHitbox(
      size: Vector2(GameConfig.designWidth - rightStart, 22),
      position: Vector2(rightStart, 8),
    ));
    // Left tower hitbox
    add(RectangleHitbox(size: Vector2(18, 40), position: Vector2(0, 0)));
    // Right tower hitbox
    add(RectangleHitbox(
      size: Vector2(18, 40),
      position: Vector2(GameConfig.designWidth - 18, 0),
    ));
  }

  @override
  void updateObstacle(double dt) {
    // Spark discharge animation logic
    _sparkTimer -= dt;
    if (_sparkTimer <= 0) {
      _sparkTimer = MathUtils.randomRange(1.8, 3.5);
      _sparkAlpha = 1.0;
      _sparkOnLeft = math.Random().nextBool();
      if (_sparkOnLeft) {
        _sparkX = MathUtils.randomRange(25, math.max(30, _gapX - 15));
      } else {
        final rightStart = _gapX + _gapWidth;
        _sparkX = MathUtils.randomRange(
            rightStart + 15, GameConfig.designWidth - 25);
      }
    }
    if (_sparkAlpha > 0) {
      _sparkAlpha = (_sparkAlpha - dt * 3.5).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rightStart = _gapX + _gapWidth;

    // 1. Draw Pylon Steel Lattice Towers on the edges
    _drawPylonTower(canvas, 0, h);
    _drawPylonTower(canvas, w - 16, h);

    // 2. Draw Sagging Catenary Cables (3 lines for high voltage look)
    final wirePaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final wireHighlight = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final sagOffsets = [8.0, 16.0, 24.0];
    for (int i = 0; i < sagOffsets.length; i++) {
      final yOff = sagOffsets[i];
      final sagAmount = 5.0 + i * 1.5;

      // Left wire segment
      final leftPath = Path()
        ..moveTo(14, yOff)
        ..quadraticBezierTo(
            _gapX * 0.5, yOff + sagAmount, _gapX, yOff + sagAmount * 0.5);
      canvas.drawPath(leftPath, wirePaint);
      canvas.drawPath(leftPath, wireHighlight);

      // Right wire segment
      final rightSpan = w - 14 - rightStart;
      final rightPath = Path()
        ..moveTo(rightStart, yOff + sagAmount * 0.5)
        ..quadraticBezierTo(
            rightStart + rightSpan * 0.5, yOff + sagAmount, w - 14, yOff);
      canvas.drawPath(rightPath, wirePaint);
      canvas.drawPath(rightPath, wireHighlight);
    }

    // 3. Draw Fluttering Aviation Marker Flags / Spheres
    _drawMarkerFlags(canvas, 0, _gapX, 16);
    _drawMarkerFlags(canvas, rightStart, w, 16);

    // 4. Draw Gap Navigation Indicators (Glowing safe corridor rings)
    _drawGapMarkers(canvas, _gapX, rightStart, 16);

    // 5. Draw Electric Spark Arc when active
    if (_sparkAlpha > 0) {
      _drawElectricSpark(canvas, _sparkX, 16, _sparkAlpha);
    }

    // Render off-screen telegraph beacon if above viewport
    renderTelegraph(canvas);
  }

  void _drawPylonTower(Canvas canvas, double x, double h) {
    final steelPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.fill;
    final trussPaint = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Upright mast
    canvas.drawRect(Rect.fromLTWH(x + 4, 0, 8, h), steelPaint);

    // Cross-arm beams
    canvas.drawRect(Rect.fromLTWH(x, 6, 16, 4), steelPaint);
    canvas.drawRect(Rect.fromLTWH(x, 14, 16, 4), steelPaint);
    canvas.drawRect(Rect.fromLTWH(x, 22, 16, 4), steelPaint);

    // Diagonal lattice truss
    canvas.drawLine(Offset(x + 4, 6), Offset(x + 12, 14), trussPaint);
    canvas.drawLine(Offset(x + 12, 14), Offset(x + 4, 22), trussPaint);

    // Ceramic insulator caps
    final insulatorPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x + 2, 8), 2.2, insulatorPaint);
    canvas.drawCircle(Offset(x + 14, 8), 2.2, insulatorPaint);
    canvas.drawCircle(Offset(x + 2, 16), 2.2, insulatorPaint);
    canvas.drawCircle(Offset(x + 14, 16), 2.2, insulatorPaint);
  }

  void _drawMarkerFlags(
      Canvas canvas, double startX, double endX, double baseH) {
    final flagPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final span = endX - startX;
    if (span < 45) return;

    final flagCount = (span / 40).floor();
    for (int i = 1; i <= flagCount; i++) {
      final fx = startX + (span / (flagCount + 1)) * i;
      final wave = math.sin(animTime * 8.0 + fx * 0.1) * 3.5;

      // Orange aviation sphere
      canvas.drawCircle(Offset(fx, baseH), 3.5, flagPaint);
      canvas.drawCircle(Offset(fx, baseH), 1.8, whitePaint);

      // Hanging fluttering triangle pennant
      final pennant = Path()
        ..moveTo(fx, baseH + 3)
        ..lineTo(fx + 5 + wave, baseH + 11)
        ..lineTo(fx, baseH + 9)
        ..close();
      canvas.drawPath(pennant, flagPaint);
    }
  }

  void _drawGapMarkers(
      Canvas canvas, double leftGapX, double rightGapX, double cy) {
    final glow = (math.sin(animTime * 6.0) * 0.35 + 0.65);
    final guidePaint = Paint()
      ..color = const Color(0xFF4FC3F7).withOpacity(glow * 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Left gap bracket
    canvas.drawCircle(Offset(leftGapX, cy), 4.5, guidePaint);
    // Right gap bracket
    canvas.drawCircle(Offset(rightGapX, cy), 4.5, guidePaint);
  }

  void _drawElectricSpark(
      Canvas canvas, double x, double y, double alpha) {
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(alpha * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final corePaint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(x, y), 10, glowPaint);

    // Jagged lightning discharge path
    final lightning = Path()..moveTo(x - 8, y + math.sin(animTime * 30) * 4);
    lightning.lineTo(x - 3, y - 5);
    lightning.lineTo(x + 2, y + 4);
    lightning.lineTo(x + 7, y - 3);
    lightning.lineTo(x + 10, y + 2);
    canvas.drawPath(lightning, corePaint);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. BuildingObstacle — Paper-Craft Skyline Towers, Rooftop HVAC Fans & Beacons
// ─────────────────────────────────────────────────────────────────────────────

/// Stylized paper-craft skyscraper buildings with animated spinning rooftop
/// HVAC exhaust fans, water towers, glowing window matrices, and pulsing red
/// aviation warning spires.
class BuildingObstacle extends ObstacleComponent {
  BuildingObstacle() : super(type: ObstacleType.building);

  double _leftWidth = 0;
  double _gapWidth = 115;
  int _style = 0; // 0 = standard modern, 1 = water tower rooftop, 2 = antenna spire

  @override
  Color get telegraphColor => const Color(0xFFE53935);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 230);
    _gapWidth = MathUtils.randomRange(100, 135);
    _leftWidth = MathUtils.randomRange(
      50,
      GameConfig.designWidth - _gapWidth - 50,
    );
    _style = math.Random().nextInt(3);
    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    // Left building block
    add(RectangleHitbox(
      size: Vector2(_leftWidth, size.y),
      position: Vector2.zero(),
    ));
    // Right building block
    final rightStart = _leftWidth + _gapWidth;
    add(RectangleHitbox(
      size: Vector2(GameConfig.designWidth - rightStart, size.y),
      position: Vector2(rightStart, 0),
    ));
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rightStart = _leftWidth + _gapWidth;
    final rightWidth = w - rightStart;

    // 1. Draw Left Skyscraper Tower
    _drawBuildingTower(canvas, 0, _leftWidth, h, isLeft: true);

    // 2. Draw Right Skyscraper Tower
    _drawBuildingTower(canvas, rightStart, rightWidth, h, isLeft: false);

    // 3. Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }

  void _drawBuildingTower(
      Canvas canvas, double startX, double bw, double bh,
      {required bool isLeft}) {
    if (bw <= 0) return;

    // Base building facade
    final facadePaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;
    final foldEdgePaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.fill;
    final trimPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.fill;

    // Main tower block
    canvas.drawRect(Rect.fromLTWH(startX, 0, bw, bh), facadePaint);

    // Paper-fold side shadow / 3D depth panel
    final sideWidth = math.min(10.0, bw * 0.2);
    if (isLeft) {
      canvas.drawRect(
          Rect.fromLTWH(startX + bw - sideWidth, 0, sideWidth, bh),
          foldEdgePaint);
    } else {
      canvas.drawRect(
          Rect.fromLTWH(startX, 0, sideWidth, bh), foldEdgePaint);
    }

    // Architectural cornices / roof edge trim
    canvas.drawRect(Rect.fromLTWH(startX, 0, bw, 8), trimPaint);
    canvas.drawRect(Rect.fromLTWH(startX, bh * 0.5, bw, 4), trimPaint);

    // Multi-window grid with glowing amber/cyan lights
    _drawLitWindows(canvas, startX + (isLeft ? 6 : sideWidth + 4),
        bw - sideWidth - 10, bh);

    // Rooftop Features (HVAC Fan, Water Tower, Spire)
    if (bw > 40) {
      if (_style == 0 || (_style == 1 && !isLeft)) {
        // Spinning HVAC Exhaust Unit
        _drawHvacFan(canvas, startX + bw * 0.4, 0);
      } else if (_style == 1 && isLeft) {
        // Wooden Cedar Water Tower
        _drawWaterTower(canvas, startX + bw * 0.35, 0);
      } else {
        // Radio Antenna Mast with Pulsing Strobe Beacon
        _drawAntennaSpire(canvas, startX + bw * 0.5, 0);
      }
    }
  }

  void _drawLitWindows(
      Canvas canvas, double startX, double usableW, double bh) {
    if (usableW < 12) return;

    const winW = 7.0;
    const winH = 9.0;
    const colGap = 15.0;
    const rowGap = 16.0;

    final warmPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;
    final cyanPaint = Paint()
      ..color = const Color(0xFF80DEEA)
      ..style = PaintingStyle.fill;
    final darkPaint = Paint()
      ..color = const Color(0xFF1E272C)
      ..style = PaintingStyle.fill;

    for (double x = startX; x < startX + usableW - winW; x += colGap) {
      for (double y = 16.0; y < bh - winH - 8; y += rowGap) {
        final hash = (x * 3.1 + y * 7.3).toInt();
        if (hash % 4 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, winW, winH), darkPaint);
        } else if (hash % 3 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, winW, winH), cyanPaint);
        } else {
          canvas.drawRect(Rect.fromLTWH(x, y, winW, winH), warmPaint);
        }
      }
    }
  }

  void _drawHvacFan(Canvas canvas, double cx, double cy) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..style = PaintingStyle.fill;
    final fanPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final cagePaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Housing box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 4), width: 22, height: 12),
        const Radius.circular(2),
      ),
      bodyPaint,
    );

    // Circular fan shroud
    canvas.drawCircle(Offset(cx, cy + 4), 4.5, cagePaint);

    // Spinning Fan Blades (16 rad/s)
    final angle = animTime * 16.0;
    canvas.save();
    canvas.translate(cx, cy + 4);
    canvas.rotate(angle);
    canvas.drawLine(const Offset(-4, 0), const Offset(4, 0), fanPaint);
    canvas.drawLine(const Offset(0, -4), const Offset(0, 4), fanPaint);
    canvas.restore();
  }

  void _drawWaterTower(Canvas canvas, double cx, double cy) {
    final woodPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.fill;
    final bandPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final roofPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;
    final legPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // Support stilts
    canvas.drawLine(Offset(cx - 8, cy + 12), Offset(cx - 6, cy + 3), legPaint);
    canvas.drawLine(Offset(cx + 8, cy + 12), Offset(cx + 6, cy + 3), legPaint);
    canvas.drawLine(Offset(cx - 6, cy + 8), Offset(cx + 6, cy + 8), legPaint);

    // Tank cylinder
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy - 2), width: 18, height: 12),
        woodPaint);
    canvas.drawLine(
        Offset(cx - 9, cy - 5), Offset(cx + 9, cy - 5), bandPaint);
    canvas.drawLine(
        Offset(cx - 9, cy + 1), Offset(cx + 9, cy + 1), bandPaint);

    // Conical roof
    final roofPath = Path()
      ..moveTo(cx - 10, cy - 8)
      ..lineTo(cx, cy - 16)
      ..lineTo(cx + 10, cy - 8)
      ..close();
    canvas.drawPath(roofPath, roofPaint);
  }

  void _drawAntennaSpire(Canvas canvas, double cx, double cy) {
    final mastPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Antenna mast line
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - 18), mastPaint);
    canvas.drawLine(
        Offset(cx - 4, cy - 8), Offset(cx + 4, cy - 8), mastPaint);

    // Blinking Aviation Strobe Beacon (red pulse)
    final pulse = (math.sin(animTime * 8.0) * 0.5 + 0.5);
    final beaconPaint = Paint()
      ..color = Color.fromRGBO(255, 23, 68, 0.4 + pulse * 0.6)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = Color.fromRGBO(255, 23, 68, pulse * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(Offset(cx, cy - 18), 7 * pulse, glowPaint);
    canvas.drawCircle(Offset(cx, cy - 18), 3.0, beaconPaint);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. TreeBranchObstacle — Organic Wind-Swaying Canopy & Falling Leaf Particles
// ─────────────────────────────────────────────────────────────────────────────

/// Lush paper-craft tree canopy branch extending horizontally into the flight
/// path, featuring multi-frequency wind swaying, organic foliage clusters,
/// paper-cut blossoms, and fluttering falling leaf drift particles.
class TreeBranchObstacle extends ObstacleComponent {
  TreeBranchObstacle() : super(type: ObstacleType.treeBranch);

  bool _fromLeft = true;
  double _branchWidth = 90;
  double _swayPhase = 0;
  final List<_LeafParticle> _fallingLeaves = [];

  @override
  Color get telegraphColor => const Color(0xFF66BB6A);

  @override
  void onActivate(double scrollSpeed) {
    _fromLeft = math.Random().nextBool();
    _branchWidth = MathUtils.randomRange(75, 125);
    size = Vector2(_branchWidth, 42);
    _swayPhase = MathUtils.randomRange(0, math.pi * 2);
    _fallingLeaves.clear();

    // Spawn anchor: left edge (0) or right edge (designWidth - width)
    if (_fromLeft) {
      position.x = 0;
    } else {
      position.x = GameConfig.designWidth - _branchWidth;
    }

    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(
      size: Vector2(size.x * 0.85, size.y * 0.7),
      position: Vector2(
        _fromLeft ? 0 : size.x * 0.15,
        size.y * 0.15,
      ),
    ));
  }

  @override
  void updateObstacle(double dt) {
    _swayPhase += dt * 3.0;

    // Periodically spawn a drifting leaf particle
    if (math.Random().nextDouble() < dt * 1.8) {
      final startX = _fromLeft
          ? MathUtils.randomRange(size.x * 0.4, size.x)
          : MathUtils.randomRange(0, size.x * 0.6);
      _fallingLeaves.add(_LeafParticle(
        x: startX,
        y: size.y * 0.5,
        vx: MathUtils.randomRange(-15, 15),
        vy: MathUtils.randomRange(30, 60),
        color: const Color(0xFF81C784),
        angle: MathUtils.randomRange(0, math.pi * 2),
      ));
    }

    // Update falling leaf particles
    for (int i = _fallingLeaves.length - 1; i >= 0; i--) {
      final leaf = _fallingLeaves[i];
      leaf.x += (leaf.vx + math.sin(animTime * 4.0 + leaf.y * 0.05) * 20.0) * dt;
      leaf.y += leaf.vy * dt;
      leaf.angle += dt * 3.0;
      leaf.life -= dt * 0.8;
      if (leaf.life <= 0 || leaf.y > 100) {
        _fallingLeaves.removeAt(i);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final sway = math.sin(_swayPhase) * 4.0;

    canvas.save();
    // Anchor rotation at base of branch attached to tree trunk off-screen
    if (_fromLeft) {
      canvas.translate(0, h * 0.5);
      canvas.rotate(sway * 0.015);
      canvas.translate(0, -h * 0.5);
    } else {
      canvas.translate(w, h * 0.5);
      canvas.rotate(-sway * 0.015);
      canvas.translate(-w, -h * 0.5);
    }

    // 1. Draw Gnarled Wood Branch
    final woodPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;
    final woodHighlight = Paint()
      ..color = const Color(0xFF795548)
      ..style = PaintingStyle.fill;

    final branchPath = Path();
    if (_fromLeft) {
      branchPath.moveTo(0, h * 0.35);
      branchPath.quadraticBezierTo(w * 0.4, h * 0.4, w * 0.8, h * 0.5);
      branchPath.lineTo(w * 0.85, h * 0.6);
      branchPath.quadraticBezierTo(w * 0.4, h * 0.65, 0, h * 0.75);
    } else {
      branchPath.moveTo(w, h * 0.35);
      branchPath.quadraticBezierTo(w * 0.6, h * 0.4, w * 0.2, h * 0.5);
      branchPath.lineTo(w * 0.15, h * 0.6);
      branchPath.quadraticBezierTo(w * 0.6, h * 0.65, w, h * 0.75);
    }
    branchPath.close();
    canvas.drawPath(branchPath, woodPaint);

    // 2. Draw Layered Foliage Clusters (Dark base, vibrant mid, sunny highlight)
    _drawFoliageClusters(canvas, w, h, sway);

    canvas.restore();

    // 3. Render falling leaves
    final leafPaint = Paint()..style = PaintingStyle.fill;
    for (final leaf in _fallingLeaves) {
      leafPaint.color = leaf.color.withOpacity(leaf.life.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(leaf.x, leaf.y);
      canvas.rotate(leaf.angle);
      canvas.drawOval(
          const Rect.fromLTWH(-3, -1.8, 6, 3.6), leafPaint);
      canvas.restore();
    }

    // Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }

  void _drawFoliageClusters(
      Canvas canvas, double w, double h, double sway) {
    final darkGreen = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    final midGreen = Paint()
      ..color = const Color(0xFF43A047)
      ..style = PaintingStyle.fill;
    final lightGreen = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;
    final flowerPaint = Paint()
      ..color = const Color(0xFFFF80AB)
      ..style = PaintingStyle.fill;

    final clusterCenters = _fromLeft
        ? [
            Offset(w * 0.35, h * 0.35),
            Offset(w * 0.65, h * 0.3),
            Offset(w * 0.85, h * 0.55),
            Offset(w * 0.5, h * 0.65),
          ]
        : [
            Offset(w * 0.65, h * 0.35),
            Offset(w * 0.35, h * 0.3),
            Offset(w * 0.15, h * 0.55),
            Offset(w * 0.5, h * 0.65),
          ];

    for (int i = 0; i < clusterCenters.length; i++) {
      final c = clusterCenters[i];
      final r = 14.0 + (i % 2) * 5.0;
      final leafSway = math.sin(_swayPhase + i * 1.2) * 2.0;

      // Dark shadow base
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx + leafSway, c.dy + 2),
            width: r * 2.0,
            height: r * 1.5),
        darkGreen,
      );

      // Mid vibrant green
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx + leafSway, c.dy),
            width: r * 1.7,
            height: r * 1.3),
        midGreen,
      );

      // Light sunlit leaf crest
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx + leafSway - 2, c.dy - 3),
            width: r * 1.2,
            height: r * 0.8),
        lightGreen,
      );

      // Cherry blossom flower / fruit accent
      if (i % 2 == 1) {
        canvas.drawCircle(
            Offset(c.dx + leafSway + 4, c.dy + 3), 3.0, flowerPaint);
      }
    }
  }
}

class _LeafParticle {
  _LeafParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.angle,
  });
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double angle;
  double life = 1.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. BirdObstacle — Animated Flapping Wings, Dynamic Swoop & Bank Rotation
// ─────────────────────────────────────────────────────────────────────────────

/// Animated avian obstacle with realistic 3-stage flapping wing cycle, smooth
/// banking into turn trajectories, swooping wave motion, and aerodynamic
/// wingtip vapor trails.
class BirdObstacle extends ObstacleComponent {
  BirdObstacle() : super(type: ObstacleType.bird);

  double _patrolAmplitude = 75;
  double _patrolFreq = 1.8;
  double _patrolPhase = 0;
  double _spawnX = 0;
  double _velocityX = 0;
  double _wingFlapPhase = 0;
  int _birdSpecies = 0; // 0 = Pigeon (City), 1 = Swallow (Backyard), 2 = Hawk (Mountain)

  @override
  Color get telegraphColor => const Color(0xFF42A5F5);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(36, 26);
    _spawnX = position.x;
    _patrolAmplitude = MathUtils.randomRange(55, 110);
    _patrolFreq = MathUtils.randomRange(1.4, 2.6);
    _patrolPhase = MathUtils.randomRange(0, math.pi * 2);
    _wingFlapPhase = MathUtils.randomRange(0, math.pi * 2);
    _birdSpecies = math.Random().nextInt(3);
    _velocityX = 0;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(
      size: Vector2(28, 20),
      position: Vector2(4, 3),
    ));
  }

  @override
  void updateObstacle(double dt) {
    _patrolPhase += _patrolFreq * dt;
    _wingFlapPhase += dt * 9.0; // Rapid wing flap frequency

    final prevX = position.x;
    final targetX = _spawnX + _patrolAmplitude * math.sin(_patrolPhase);
    position.x = targetX.clamp(
      GameConfig.horizontalEdgeMargin + 10,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 10,
    );

    // Calculate lateral velocity for banking tilt
    _velocityX = (position.x - prevX) / math.max(0.001, dt);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Bank angle tilt based on velocity direction
    final bankAngle = (_velocityX * 0.0018).clamp(-0.45, 0.45);

    // Flapping wing elevation angle [-1 = full upstroke, 1 = full downstroke]
    final flapAmount = math.sin(_wingFlapPhase);

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(bankAngle);

    // Species color theme
    final Color bodyColor;
    final Color wingColor;
    final Color wingTipColor;

    if (_birdSpecies == 1) {
      // Golden / Amber Swallow
      bodyColor = const Color(0xFFFFA000);
      wingColor = const Color(0xFFFFB300);
      wingTipColor = const Color(0xFF5D4037);
    } else if (_birdSpecies == 2) {
      // Crimson / Hawk
      bodyColor = const Color(0xFF8D6E63);
      wingColor = const Color(0xFFA1887F);
      wingTipColor = const Color(0xFFD32F2F);
    } else {
      // Slate Blue City Pigeon
      bodyColor = const Color(0xFF607D8B);
      wingColor = const Color(0xFF78909C);
      wingTipColor = const Color(0xFF455A64);
    }

    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    final wingPaint = Paint()
      ..color = wingColor
      ..style = PaintingStyle.fill;
    final tipPaint = Paint()
      ..color = wingTipColor
      ..style = PaintingStyle.fill;

    // 1. Tail Feathers (Flared split tail)
    final tail = Path()
      ..moveTo(0, 4)
      ..lineTo(-6, 12)
      ..lineTo(0, 9)
      ..lineTo(6, 12)
      ..close();
    canvas.drawPath(tail, tipPaint);

    // 2. Left Wing (Animated up/down flap geometry)
    final wingY = flapAmount * 8.0;
    final leftWing = Path()
      ..moveTo(-4, 0)
      ..quadraticBezierTo(-10, wingY - 6, -18, wingY - 2)
      ..lineTo(-15, wingY + 4)
      ..lineTo(-3, 3)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Left wingtip accent
    final leftTip = Path()
      ..moveTo(-12, wingY - 4)
      ..lineTo(-18, wingY - 2)
      ..lineTo(-15, wingY + 4)
      ..close();
    canvas.drawPath(leftTip, tipPaint);

    // 3. Right Wing (Mirrored animated flap)
    final rightWing = Path()
      ..moveTo(4, 0)
      ..quadraticBezierTo(10, wingY - 6, 18, wingY - 2)
      ..lineTo(15, wingY + 4)
      ..lineTo(3, 3)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Right wingtip accent
    final rightTip = Path()
      ..moveTo(12, wingY - 4)
      ..lineTo(18, wingY - 2)
      ..lineTo(15, wingY + 4)
      ..close();
    canvas.drawPath(rightTip, tipPaint);

    // 4. Main Fuselage Body
    canvas.drawOval(
      const Rect.fromLTWH(-5, -8, 10, 16),
      bodyPaint,
    );

    // 5. Head & Golden Beak
    canvas.drawCircle(const Offset(0, -7), 4.2, bodyPaint);
    final beakPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;
    final beak = Path()
      ..moveTo(-2, -9)
      ..lineTo(0, -14)
      ..lineTo(2, -9)
      ..close();
    canvas.drawPath(beak, beakPaint);

    // Eye with catchlight
    final eyePaint = Paint()..color = const Color(0xFF212121);
    final glintPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(const Offset(-1.6, -7.5), 1.2, eyePaint);
    canvas.drawCircle(const Offset(1.6, -7.5), 1.2, eyePaint);
    canvas.drawCircle(const Offset(-1.8, -7.8), 0.5, glintPaint);
    canvas.drawCircle(const Offset(1.4, -7.8), 0.5, glintPaint);

    canvas.restore();

    // Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. DroneObstacle — Spinning Quadcopter Rotors, Searchlight Beam & Alert Strobe
// ─────────────────────────────────────────────────────────────────────────────

/// High-tech quadcopter drone obstacle with spinning propeller discs, dynamic
/// player tracking, physical banking lean, pulsing alert beacon, and an
/// illuminated conical searchlight scanning beam.
class DroneObstacle extends ObstacleComponent {
  DroneObstacle() : super(type: ObstacleType.drone);

  double _trackingDuration = 3.2;
  double _trackingTimer = 0;
  double _velocityX = 0;
  bool _isLockedOn = false;

  @override
  Color get telegraphColor => const Color(0xFFFF1744);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(38, 28);
    _trackingDuration = MathUtils.randomRange(2.5, 4.2);
    _trackingTimer = 0;
    _velocityX = 0;
    _isLockedOn = false;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(
      size: Vector2(30, 22),
      position: Vector2(4, 3),
    ));
  }

  @override
  void updateObstacle(double dt) {
    if (_trackingTimer < _trackingDuration) {
      _trackingTimer += dt;
      // Track player X coordinate with smooth response
      final targetX = gameRef.plane.position.x;
      final diff = targetX - position.x;
      _isLockedOn = diff.abs() < 40.0;
      _velocityX = MathUtils.lerp(_velocityX, diff * 1.8, 0.10);
      position.x = (position.x + _velocityX * dt).clamp(
        GameConfig.horizontalEdgeMargin + 15,
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 15,
      );
    } else {
      _isLockedOn = false;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Physical banking lean into acceleration
    final tiltAngle = (_velocityX * 0.0022).clamp(-0.4, 0.4);

    // 1. Draw Downward Translucent Conical Searchlight Beam
    _drawSearchlightBeam(canvas, w * 0.5, h * 0.5, tiltAngle);

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(tiltAngle);

    // 2. Drone Arm Struts
    final armPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-14, -10), const Offset(14, 10), armPaint);
    canvas.drawLine(const Offset(-14, 10), const Offset(14, -10), armPaint);

    // 3. Central Chassis Body
    final bodyPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;
    final stripePaint = Paint()
      ..color = const Color(0xFFFFCA28)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -7, 18, 14),
        const Radius.circular(3),
      ),
      bodyPaint,
    );

    // High-visibility hazard stripes on chassis
    canvas.drawRect(const Rect.fromLTWH(-6, -2, 12, 4), stripePaint);

    // Center optical sensor camera lens
    final lensPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, 2), 3.0, lensPaint);

    // 4. Four Spinning Propeller Rotors
    final rotorOffsets = [
      const Offset(-14, -10),
      const Offset(14, -10),
      const Offset(-14, 10),
      const Offset(14, 10),
    ];
    for (final ro in rotorOffsets) {
      _drawSpinningRotor(canvas, ro);
    }

    // 5. Pulsing Status / Alert Strobe Beacon
    final strobeFreq = _isLockedOn ? 18.0 : 6.0;
    final strobePulse = (math.sin(animTime * strobeFreq) * 0.5 + 0.5);
    final beaconColor = _isLockedOn
        ? Color.fromRGBO(255, 23, 68, 0.4 + strobePulse * 0.6)
        : Color.fromRGBO(0, 229, 255, 0.4 + strobePulse * 0.6);
    final beaconPaint = Paint()
      ..color = beaconColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(0, -7), 3.5 * strobePulse, beaconPaint);
    canvas.drawCircle(const Offset(0, -7), 1.5, beaconPaint);

    canvas.restore();

    // Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }

  void _drawSpinningRotor(Canvas canvas, Offset pos) {
    final hubPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.fill;
    final blurPaint = Paint()
      ..color = const Color(0x66B0BEC5)
      ..style = PaintingStyle.fill;
    final bladePaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Motor pod hub
    canvas.drawCircle(pos, 3.2, hubPaint);

    // Motion blur propeller disk
    canvas.drawOval(
      Rect.fromCenter(center: pos, width: 16, height: 6),
      blurPaint,
    );

    // Spinning blade crossbar
    final bladeAngle = animTime * 35.0;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(bladeAngle);
    canvas.drawLine(const Offset(-7, 0), const Offset(7, 0), bladePaint);
    canvas.restore();
  }

  void _drawSearchlightBeam(
      Canvas canvas, double cx, double cy, double tilt) {
    final beamLength = 160.0;
    final beamSpread = 45.0;

    final beamPaint = Paint()
      ..shader = Gradient.linear(
        Offset(cx, cy),
        Offset(cx + math.sin(tilt) * beamLength, cy + beamLength),
        [
          const Color(0x6600E5FF),
          const Color(0x1500E5FF),
          const Color(0x0000E5FF),
        ],
        [0.0, 0.6, 1.0],
      )
      ..style = PaintingStyle.fill;

    final beamPath = Path()
      ..moveTo(cx - 4, cy + 4)
      ..lineTo(cx - beamSpread, cy + beamLength)
      ..lineTo(cx + beamSpread, cy + beamLength)
      ..lineTo(cx + 4, cy + 4)
      ..close();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt * 0.7);
    canvas.translate(-cx, -cy);
    canvas.drawPath(beamPath, beamPaint);
    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. WindTurbineObstacle — Giant 3-Blade Rotating Turbine / Aerogenerator
// ─────────────────────────────────────────────────────────────────────────────

/// Massive 3-blade industrial wind turbine / paper pinwheel creating an exciting
/// timing challenge where players fly through the opening between spinning blades.
class WindTurbineObstacle extends ObstacleComponent {
  WindTurbineObstacle() : super(type: ObstacleType.windTurbine);

  double _bladeAngle = 0;
  double _rotSpeed = 1.4; // rad/s
  double _bladeRadius = 65;

  @override
  Color get telegraphColor => const Color(0xFF00E676);

  @override
  void onActivate(double scrollSpeed) {
    _bladeRadius = MathUtils.randomRange(60, 78);
    size = Vector2(_bladeRadius * 2.2, _bladeRadius * 2.2 + 60);
    _bladeAngle = MathUtils.randomRange(0, math.pi * 2);
    _rotSpeed = MathUtils.randomRange(1.2, 1.9) * (math.Random().nextBool() ? 1 : -1);

    removeAll(children.whereType<ShapeHitbox>().toList());
    // Central hub & mast hitbox
    add(CircleHitbox(
      radius: 14,
      position: Vector2(size.x * 0.5 - 14, _bladeRadius - 14),
    ));
    add(RectangleHitbox(
      size: Vector2(16, 60),
      position: Vector2(size.x * 0.5 - 8, _bladeRadius),
    ));
  }

  @override
  void updateObstacle(double dt) {
    _bladeAngle += _rotSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = _bladeRadius;

    // 1. Tower Mast Base Pylon
    final mastPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..style = PaintingStyle.fill;
    final mastShadow = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.fill;

    final mast = Path()
      ..moveTo(cx - 7, cy)
      ..lineTo(cx - 12, size.y)
      ..lineTo(cx + 12, size.y)
      ..lineTo(cx + 7, cy)
      ..close();
    canvas.drawPath(mast, mastPaint);

    final mastSide = Path()
      ..moveTo(cx + 2, cy)
      ..lineTo(cx + 4, size.y)
      ..lineTo(cx + 12, size.y)
      ..lineTo(cx + 7, cy)
      ..close();
    canvas.drawPath(mastSide, mastShadow);

    // 2. Streamlined Nacelle Housing
    final nacellePaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 24, height: 16),
        const Radius.circular(4),
      ),
      nacellePaint,
    );

    // 3. Three Rotating Aerodynamic Blades (120 deg apart)
    for (int i = 0; i < 3; i++) {
      final angle = _bladeAngle + i * (math.pi * 2 / 3);
      _drawAerodynamicBlade(canvas, cx, cy, angle, _bladeRadius);
    }

    // 4. Central Spinner Nose Cone
    final hubPaint = Paint()
      ..color = const Color(0xFFFAFAFA)
      ..style = PaintingStyle.fill;
    final hubRim = Paint()
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(cx, cy), 8.0, hubPaint);
    canvas.drawCircle(Offset(cx, cy), 8.0, hubRim);

    // 5. Blinking Red Aviation Beacon on Nacelle
    final beaconPulse = (math.sin(animTime * 7.0) * 0.5 + 0.5);
    final beaconPaint = Paint()
      ..color = Color.fromRGBO(255, 23, 68, 0.3 + beaconPulse * 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy - 8), 2.5, beaconPaint);

    // Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }

  void _drawAerodynamicBlade(
      Canvas canvas, double cx, double cy, double angle, double length) {
    final bladePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final bladeBevel = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    final stripePaint = Paint()
      ..color = const Color(0xFFFF3D00)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Tapered aerofoil blade shape
    final blade = Path()
      ..moveTo(-3, 0)
      ..quadraticBezierTo(-6, length * 0.6, -2, length)
      ..lineTo(0, length + 3)
      ..lineTo(2, length)
      ..quadraticBezierTo(4, length * 0.6, 3, 0)
      ..close();
    canvas.drawPath(blade, bladePaint);

    // Fold / bevel shadow side
    final bevel = Path()
      ..moveTo(0, 0)
      ..lineTo(0, length + 3)
      ..lineTo(2, length)
      ..quadraticBezierTo(4, length * 0.6, 3, 0)
      ..close();
    canvas.drawPath(bevel, bladeBevel);

    // Red high-visibility hazard warning stripes at blade tip
    canvas.drawRect(Rect.fromLTWH(-2.5, length * 0.75, 5, 4), stripePaint);
    canvas.drawRect(Rect.fromLTWH(-2.0, length * 0.88, 4, 4), stripePaint);

    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. HotAirBalloonObstacle — Paper-Craft Striped Balloon, Burner Flame & Basket
// ─────────────────────────────────────────────────────────────────────────────

/// Majestic floating hot air balloon / sky lantern with colorful paper vertical
/// stripes, animated flickering burner flame, rigging suspension cables, and
/// woven wicker basket.
class HotAirBalloonObstacle extends ObstacleComponent {
  HotAirBalloonObstacle() : super(type: ObstacleType.hotAirBalloon);

  double _driftPhase = 0;
  double _driftAmp = 35;
  double _spawnX = 0;
  int _colorTheme = 0;

  @override
  Color get telegraphColor => const Color(0xFFFF7043);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(72, 96);
    _spawnX = position.x;
    _driftAmp = MathUtils.randomRange(25, 45);
    _driftPhase = MathUtils.randomRange(0, math.pi * 2);
    _colorTheme = math.Random().nextInt(3);

    removeAll(children.whereType<ShapeHitbox>().toList());
    // Balloon envelope hitbox
    add(CircleHitbox(
      radius: 32,
      position: Vector2(size.x * 0.5 - 32, 4),
    ));
    // Basket hitbox
    add(RectangleHitbox(
      size: Vector2(22, 18),
      position: Vector2(size.x * 0.5 - 11, 74),
    ));
  }

  @override
  void updateObstacle(double dt) {
    _driftPhase += dt * 1.2;
    position.x = (_spawnX + math.sin(_driftPhase) * _driftAmp).clamp(
      GameConfig.horizontalEdgeMargin + 30,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 30,
    );
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = 34.0;
    final basketY = 82.0;

    // 1. Rigging Suspension Ropes
    final ropePaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 16, cy + 24), Offset(cx - 8, basketY), ropePaint);
    canvas.drawLine(Offset(cx - 6, cy + 26), Offset(cx - 4, basketY), ropePaint);
    canvas.drawLine(Offset(cx + 6, cy + 26), Offset(cx + 4, basketY), ropePaint);
    canvas.drawLine(Offset(cx + 16, cy + 24), Offset(cx + 8, basketY), ropePaint);

    // 2. Animated Burner Flame (Flickering blue/yellow/orange fire)
    _drawBurnerFlame(canvas, cx, cy + 27);

    // 3. Balloon Teardrop Envelope
    _drawBalloonEnvelope(canvas, cx, cy);

    // 4. Woven Wicker Basket Gondola
    _drawWickerBasket(canvas, cx, basketY);

    // Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }

  void _drawBalloonEnvelope(Canvas canvas, double cx, double cy) {
    final List<Color> palette;
    if (_colorTheme == 1) {
      palette = [
        const Color(0xFF00ACC1), // Cyan
        const Color(0xFFFFB300), // Amber
        const Color(0xFFE53935), // Red
      ];
    } else if (_colorTheme == 2) {
      palette = [
        const Color(0xFF8E24AA), // Violet
        const Color(0xFFFF7043), // Coral
        const Color(0xFFFFD54F), // Gold
      ];
    } else {
      palette = [
        const Color(0xFFE53935), // Crimson
        const Color(0xFFFDD835), // Gold
        const Color(0xFF1E88E5), // Blue
      ];
    }

    // Outer envelope base shape
    final envelopePath = Path()
      ..moveTo(cx - 14, cy + 24)
      ..cubicTo(cx - 36, cy + 10, cx - 36, cy - 26, cx, cy - 28)
      ..cubicTo(cx + 36, cy - 26, cx + 36, cy + 10, cx + 14, cy + 24)
      ..close();

    final bgPaint = Paint()
      ..color = palette[0]
      ..style = PaintingStyle.fill;
    canvas.drawPath(envelopePath, bgPaint);

    // Vertical striped gores (Paper panels)
    final midPaint = Paint()
      ..color = palette[1]
      ..style = PaintingStyle.fill;
    final centerPaint = Paint()
      ..color = palette[2]
      ..style = PaintingStyle.fill;

    final midGore = Path()
      ..moveTo(cx - 8, cy + 24)
      ..cubicTo(cx - 20, cy + 8, cx - 20, cy - 25, cx, cy - 28)
      ..cubicTo(cx + 20, cy - 25, cx + 20, cy + 8, cx + 8, cy + 24)
      ..close();
    canvas.drawPath(midGore, midPaint);

    final centerGore = Path()
      ..moveTo(cx - 4, cy + 24)
      ..cubicTo(cx - 9, cy + 6, cx - 9, cy - 26, cx, cy - 28)
      ..cubicTo(cx + 9, cy - 26, cx + 9, cy + 6, cx + 4, cy + 24)
      ..close();
    canvas.drawPath(centerGore, centerPaint);

    // Scalloped bottom rim skirt
    final skirtPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + 24), width: 28, height: 4),
      skirtPaint,
    );
  }

  void _drawBurnerFlame(Canvas canvas, double cx, double cy) {
    final flameFlicker = (math.sin(animTime * 20.0) * 0.4 + 0.6);
    final h = 14.0 * flameFlicker;

    final outerFlame = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;
    final innerFlame = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;
    final coreFlame = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    final flamePath = Path()
      ..moveTo(cx - 4, cy)
      ..quadraticBezierTo(cx - 6, cy - h * 0.5, cx, cy - h)
      ..quadraticBezierTo(cx + 6, cy - h * 0.5, cx + 4, cy)
      ..close();
    canvas.drawPath(flamePath, outerFlame);

    final innerPath = Path()
      ..moveTo(cx - 2.5, cy)
      ..quadraticBezierTo(cx - 3.5, cy - h * 0.4, cx, cy - h * 0.75)
      ..quadraticBezierTo(cx + 3.5, cy - h * 0.4, cx + 2.5, cy)
      ..close();
    canvas.drawPath(innerPath, innerFlame);

    canvas.drawCircle(Offset(cx, cy - 2), 2.0, coreFlame);
  }

  void _drawWickerBasket(Canvas canvas, double cx, double cy) {
    final basketPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.fill;
    final weavePaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final rimPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.fill;

    // Basket body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 14),
        const Radius.circular(2),
      ),
      basketPaint,
    );

    // Weave texture lines
    canvas.drawLine(Offset(cx - 10, cy - 2), Offset(cx + 10, cy - 2), weavePaint);
    canvas.drawLine(Offset(cx - 10, cy + 3), Offset(cx + 10, cy + 3), weavePaint);
    canvas.drawLine(Offset(cx - 4, cy - 7), Offset(cx - 4, cy + 7), weavePaint);
    canvas.drawLine(Offset(cx + 4, cy - 7), Offset(cx + 4, cy + 7), weavePaint);

    // Top rim collar
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy - 7), width: 22, height: 3),
      rimPaint,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. StormCloudObstacle — Billowing Electric Cloud, Lightning & Rain Streaks
// ─────────────────────────────────────────────────────────────────────────────

/// Dark, billowing storm thundercloud obstacle with internal electric charge
/// buildup, crackling lightning discharge strikes, and falling rain streaks.
class StormCloudObstacle extends ObstacleComponent {
  StormCloudObstacle() : super(type: ObstacleType.stormCloud);

  double _chargeTimer = 0;
  double _lightningAlpha = 0;
  List<Offset> _lightningPoints = [];

  @override
  Color get telegraphColor => const Color(0xFF7C4DFF);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(100, 55);
    _chargeTimer = MathUtils.randomRange(1.2, 2.5);
    _lightningAlpha = 0;
    _lightningPoints = [];

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 24, position: Vector2(8, 4)));
    add(CircleHitbox(radius: 28, position: Vector2(size.x * 0.5 - 28, 0)));
    add(CircleHitbox(radius: 22, position: Vector2(size.x - 52, 6)));
  }

  @override
  void updateObstacle(double dt) {
    _chargeTimer -= dt;
    if (_chargeTimer <= 0) {
      _chargeTimer = MathUtils.randomRange(2.0, 3.8);
      _lightningAlpha = 1.0;
      _generateLightningStrike();
    }
    if (_lightningAlpha > 0) {
      _lightningAlpha = (_lightningAlpha - dt * 4.0).clamp(0.0, 1.0);
    }
  }

  void _generateLightningStrike() {
    _lightningPoints = [
      Offset(size.x * 0.5, size.y * 0.6),
      Offset(size.x * 0.45, size.y * 0.9),
      Offset(size.x * 0.55, size.y * 1.2),
      Offset(size.x * 0.48, size.y * 1.5),
      Offset(size.x * 0.52, size.y * 1.8),
    ];
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;

    // 1. Rain Streaks falling from cloud base
    _drawRainStreaks(canvas, size.x, size.y);

    // 2. Multi-Lobed Dark Storm Cloud Mass
    final baseCloud = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;
    final midCloud = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.fill;
    final topHighlight = Paint()
      ..color = const Color(0xFF546E7A)
      ..style = PaintingStyle.fill;

    // Charge glow inside cloud before strike
    final chargePulse = (math.sin(animTime * 12.0) * 0.5 + 0.5);
    final chargePaint = Paint()
      ..color = Color.fromRGBO(124, 77, 255, 0.25 + chargePulse * 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(cx, cy), 32, chargePaint);

    // Cloud lobes
    final lobes = [
      Offset(cx - 26, cy + 4),
      Offset(cx - 14, cy - 8),
      Offset(cx + 12, cy - 10),
      Offset(cx + 26, cy + 4),
      Offset(cx, cy + 8),
    ];
    final radii = [22.0, 26.0, 28.0, 20.0, 25.0];

    for (int i = 0; i < lobes.length; i++) {
      canvas.drawCircle(lobes[i], radii[i], baseCloud);
    }
    for (int i = 0; i < lobes.length; i++) {
      canvas.drawCircle(Offset(lobes[i].dx, lobes[i].dy - 3), radii[i] * 0.82, midCloud);
    }
    for (int i = 0; i < lobes.length; i++) {
      canvas.drawCircle(Offset(lobes[i].dx - 2, lobes[i].dy - 6), radii[i] * 0.5, topHighlight);
    }

    // 3. Lightning Strike Arc
    if (_lightningAlpha > 0 && _lightningPoints.length >= 2) {
      final glowPaint = Paint()
        ..color = Color.fromRGBO(0, 229, 255, _lightningAlpha * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final corePaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, _lightningAlpha)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(_lightningPoints[0].dx, _lightningPoints[0].dy);
      for (int i = 1; i < _lightningPoints.length; i++) {
        path.lineTo(_lightningPoints[i].dx, _lightningPoints[i].dy);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);
    }

    // Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }

  void _drawRainStreaks(Canvas canvas, double w, double h) {
    final rainPaint = Paint()
      ..color = const Color(0x6680DEEA)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 7; i++) {
      final rx = (i * 14.0 + 8.0) % w;
      final ry = h * 0.7 + (animTime * 120.0 + i * 15.0) % 40.0;
      canvas.drawLine(Offset(rx, ry), Offset(rx - 4, ry + 12), rainPaint);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. KiteObstacle — Festival Diamond Kite with Dynamic Physics Ribbon Tail
// ─────────────────────────────────────────────────────────────────────────────

/// Vibrant festival diamond paper kite caught in gusts, featuring dynamic wave
/// cloth ribbon tail with colorful decorative bows.
class KiteObstacle extends ObstacleComponent {
  KiteObstacle() : super(type: ObstacleType.kite);

  double _flutterPhase = 0;
  double _spawnX = 0;
  double _driftAmp = 50;

  @override
  Color get telegraphColor => const Color(0xFFFF4081);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(40, 110);
    _spawnX = position.x;
    _driftAmp = MathUtils.randomRange(35, 65);
    _flutterPhase = MathUtils.randomRange(0, math.pi * 2);

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(
      size: Vector2(28, 36),
      position: Vector2(6, 4),
    ));
  }

  @override
  void updateObstacle(double dt) {
    _flutterPhase += dt * 3.5;
    position.x = (_spawnX + math.sin(_flutterPhase) * _driftAmp).clamp(
      GameConfig.horizontalEdgeMargin + 20,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 20,
    );
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final kiteY = 20.0;
    final tilt = math.sin(_flutterPhase) * 0.25;

    // 1. Dynamic Flowing Physics Ribbon Tail with Bows
    _drawRibbonTail(canvas, cx, kiteY + 16);

    canvas.save();
    canvas.translate(cx, kiteY);
    canvas.rotate(tilt);

    // 2. Diamond Kite Facets
    final topPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;
    final leftPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;
    final rightPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final botPaint = Paint()
      ..color = const Color(0xFF7C4DFF)
      ..style = PaintingStyle.fill;
    final strutPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Top triangle facet
    final topF = Path()..moveTo(0, -18)..lineTo(-14, 0)..lineTo(0, 0)..close();
    canvas.drawPath(topF, topPaint);

    final rightTopF = Path()..moveTo(0, -18)..lineTo(14, 0)..lineTo(0, 0)..close();
    canvas.drawPath(rightTopF, rightPaint);

    // Bottom triangle facet
    final botLeftF = Path()..moveTo(-14, 0)..lineTo(0, 18)..lineTo(0, 0)..close();
    canvas.drawPath(botLeftF, leftPaint);

    final botRightF = Path()..moveTo(14, 0)..lineTo(0, 18)..lineTo(0, 0)..close();
    canvas.drawPath(botRightF, botPaint);

    // Bamboo cross-struts
    canvas.drawLine(const Offset(0, -18), const Offset(0, 18), strutPaint);
    canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), strutPaint);

    canvas.restore();

    // Render off-screen telegraph if descending from above
    renderTelegraph(canvas);
  }

  void _drawRibbonTail(Canvas canvas, double cx, double startY) {
    final tailPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final bowColors = [
      const Color(0xFFFF1744),
      const Color(0xFFFFEA00),
      const Color(0xFF00E676),
      const Color(0xFF2979FF),
      const Color(0xFFFF9100),
    ];

    final tailPath = Path()..moveTo(cx, startY);
    const nodeCount = 5;
    const nodeSpacing = 16.0;

    for (int i = 1; i <= nodeCount; i++) {
      final ny = startY + i * nodeSpacing;
      final wave = math.sin(_flutterPhase - i * 0.7) * (10.0 + i * 2.0);
      final nx = cx + wave;
      tailPath.lineTo(nx, ny);

      // Draw ribbon bow
      final bowPaint = Paint()
        ..color = bowColors[(i - 1) % bowColors.length]
        ..style = PaintingStyle.fill;
      final bow = Path()
        ..moveTo(nx - 4, ny - 3)
        ..lineTo(nx + 4, ny + 3)
        ..lineTo(nx + 4, ny - 3)
        ..lineTo(nx - 4, ny + 3)
        ..close();
      canvas.drawPath(bow, bowPaint);
    }
    canvas.drawPath(tailPath, tailPaint);
  }
}
