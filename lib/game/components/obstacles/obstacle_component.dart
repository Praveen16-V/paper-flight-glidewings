import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

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
///  - Calls [onRecycle] when it exits the bottom of the viewport so the
///    spawner can return it to the pool.
abstract class ObstacleComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  ObstacleComponent({required this.type}) : super(anchor: Anchor.topCenter);

  final ObstacleType type;

  bool _active = false;
  bool _nearMissAwarded = false;
  void Function(ObstacleComponent)? onRecycle;

  bool get isActive => _active;

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
    onRecycle = recycleCallback;
    onActivate(scrollSpeed);
  }

  void deactivate() {
    _active = false;
    onRecycle = null;
    _nearMissAwarded = false;
  }

  /// Override in subclasses to set dynamic-specific state (patrol patterns etc).
  void onActivate(double scrollSpeed) {}

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_active) return;

    // Scroll downward with the world (use effective speed for turbo/slow-mo).
    final speed = game.effectiveScrollSpeed;
    position.y += speed * dt;

    // Subclass-specific movement (birds patrol, drones track, etc.).
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
      if (other.isInvulnerable) return;
      game.onPlaneCrash();
    }
  }

  // ── Near-Miss ──────────────────────────────────────────────────────────────

  void _checkNearMiss() {
    if (_nearMissAwarded) return;
    final plane = game.plane;
    if (!plane.isMounted) return;

    // Use closest edge distance for multi-hitbox obstacles.
    final planePos = plane.position;
    final obsCenter = absoluteCenter;
    final dist = MathUtils.distance(
      planePos.x,
      planePos.y,
      obsCenter.x,
      obsCenter.y,
    );

    // Near-miss: plane is close horizontally and has roughly passed the obstacle
    // vertically without colliding.
    final halfH = size.y * 0.5 + plane.size.y * 0.5;
    final halfW = size.x * 0.5 + plane.size.x * 0.5;
    final verticalPassed = (planePos.y - obsCenter.y).abs() < halfH + GameConfig.nearMissDistance;
    final horizontalClose = (planePos.x - obsCenter.x).abs() < halfW + GameConfig.nearMissDistance;

    if (verticalPassed &&
        horizontalClose &&
        dist < GameConfig.nearMissDistance + math.max(size.x, size.y) * 0.5 &&
        dist > GameConfig.nearMissDistance * 0.25) {
      _nearMissAwarded = true;
      game.scoringSystem.onNearMiss();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete obstacle types
// ─────────────────────────────────────────────────────────────────────────────

/// Horizontal power line that spans most of the screen width with a gap.
class PowerLineObstacle extends ObstacleComponent {
  PowerLineObstacle() : super(type: ObstacleType.powerLine);

  double _gapX = 0;
  double _gapWidth = 90;

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 14);
    // Anchor is topCenter — position.x is the centre of the full-width line.
    position.x = GameConfig.designWidth / 2;
    _gapWidth = MathUtils.randomRange(80, 120);
    _gapX = MathUtils.randomRange(
      GameConfig.horizontalEdgeMargin * 2,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin * 2 - _gapWidth,
    );
    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    // Left segment hitbox (local coords: origin at top-left of component)
    add(RectangleHitbox(
      size: Vector2(_gapX, 14),
      position: Vector2.zero(),
    ));
    // Right segment hitbox
    final rightStart = _gapX + _gapWidth;
    add(RectangleHitbox(
      size: Vector2(GameConfig.designWidth - rightStart, 14),
      position: Vector2(rightStart, 0),
    ));
  }

  @override
  void render(Canvas canvas) {
    final linePaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final polePaint = Paint()
      ..color = const Color(0xFF78909C)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;

    // Left segment
    canvas.drawLine(Offset(0, h / 2), Offset(_gapX, h / 2), linePaint);
    // Right segment
    final rightStart = _gapX + _gapWidth;
    canvas.drawLine(
        Offset(rightStart, h / 2), Offset(w, h / 2), linePaint);
    // Poles
    canvas.drawRect(Rect.fromLTWH(4, 0, 6, h), polePaint);
    canvas.drawRect(Rect.fromLTWH(w - 10, 0, 6, h), polePaint);
    // Insulators at gap edges
    final insulatorPaint = Paint()..color = const Color(0xFFB0BEC5);
    canvas.drawCircle(Offset(_gapX, h / 2), 4, insulatorPaint);
    canvas.drawCircle(Offset(rightStart, h / 2), 4, insulatorPaint);
  }
}

/// Building pair — two tall buildings with a gap the plane must fly through.
class BuildingObstacle extends ObstacleComponent {
  BuildingObstacle() : super(type: ObstacleType.building);

  double _leftWidth = 0;
  double _gapWidth = 110;

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 200);
    position.x = GameConfig.designWidth / 2;
    _gapWidth = MathUtils.randomRange(95, 140);
    _leftWidth = MathUtils.randomRange(
      40,
      GameConfig.designWidth - _gapWidth - 40,
    );
    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(
      size: Vector2(_leftWidth, size.y),
      position: Vector2.zero(),
    ));
    final rightStart = _leftWidth + _gapWidth;
    add(RectangleHitbox(
      size: Vector2(GameConfig.designWidth - rightStart, size.y),
      position: Vector2(rightStart, 0),
    ));
  }

  @override
  void render(Canvas canvas) {
    final buildingPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.fill;
    final windowPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;
    final roofPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;
    final rightStart = _leftWidth + _gapWidth;

    // Left building
    canvas.drawRect(Rect.fromLTWH(0, 0, _leftWidth, h), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, _leftWidth, 8), roofPaint);
    // Right building
    canvas.drawRect(
        Rect.fromLTWH(rightStart, 0, w - rightStart, h), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(rightStart, 0, w - rightStart, 8), roofPaint);

    _drawWindows(canvas, windowPaint, 0, _leftWidth, h);
    _drawWindows(canvas, windowPaint, rightStart, w - rightStart, h);
  }

  void _drawWindows(
      Canvas canvas, Paint paint, double startX, double bw, double bh) {
    const winW = 6.0;
    const winH = 5.0;
    const colGap = 14.0;
    const rowGap = 12.0;
    for (double x = startX + 8; x < startX + bw - winW - 4; x += colGap) {
      for (double y = 12.0; y < bh - winH - 4; y += rowGap) {
        if ((x + y).toInt() % 5 != 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, winW, winH), paint);
        }
      }
    }
  }
}

/// Tree branch — hangs from a side of the screen.
class TreeBranchObstacle extends ObstacleComponent {
  TreeBranchObstacle() : super(type: ObstacleType.treeBranch);

  bool _fromTop = true;
  double _branchWidth = 60;

  @override
  void onActivate(double scrollSpeed) {
    _fromTop = MathUtils.randomRange(0, 1) > 0.5;
    _branchWidth = MathUtils.randomRange(50, 100);
    size = Vector2(_branchWidth, 24);
    // Keep spawn X from activator (already set).
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size));
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
    final branchPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;

    canvas.drawRect(Rect.fromLTWH(w * 0.45, 0, w * 0.1, h), branchPaint);
    canvas.drawOval(
        Rect.fromLTWH(0, _fromTop ? 0 : h * 0.3, w, h * 0.7), paint);
  }
}

/// Bird — patrols a horizontal lane, swooping left-right.
class BirdObstacle extends ObstacleComponent {
  BirdObstacle() : super(type: ObstacleType.bird);

  double _patrolAmplitude = 60;
  double _patrolFreq = 1.5;
  double _patrolPhase = 0;
  double _spawnX = 0;
  double _wingFlap = 0;

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(30, 18);
    _spawnX = position.x;
    _patrolAmplitude = MathUtils.randomRange(40, 90);
    _patrolFreq = MathUtils.randomRange(1.0, 2.5);
    _patrolPhase = MathUtils.randomRange(0, 6.28);
    _wingFlap = 0;
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size * 0.7, position: size * 0.15));
  }

  @override
  void updateObstacle(double dt) {
    _patrolPhase += _patrolFreq * dt;
    _wingFlap += dt * 12;
    position.x = (_spawnX + _patrolAmplitude * math.sin(_patrolPhase)).clamp(
      GameConfig.horizontalEdgeMargin,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin,
    );
  }

  @override
  void render(Canvas canvas) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;
    final flap = math.sin(_wingFlap) * 4;

    // Body
    canvas.drawOval(
        Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.4, h * 0.6), bodyPaint);
    // Left wing
    final path = Path()
      ..moveTo(w * 0.3, h * 0.4)
      ..quadraticBezierTo(0, flap, 0, h * 0.3 + flap)
      ..lineTo(w * 0.3, h * 0.5);
    canvas.drawPath(path, bodyPaint);
    // Right wing
    final path2 = Path()
      ..moveTo(w * 0.7, h * 0.4)
      ..quadraticBezierTo(w, flap, w, h * 0.3 + flap)
      ..lineTo(w * 0.7, h * 0.5);
    canvas.drawPath(path2, bodyPaint);
  }
}

/// Drone — tracks the player horizontally for a few seconds before going
/// straight, making it a skill-test obstacle.
class DroneObstacle extends ObstacleComponent {
  DroneObstacle() : super(type: ObstacleType.drone);

  double _trackingDuration = 3.0;
  double _trackingTimer = 0;
  double _velocityX = 0;
  double _rotorSpin = 0;

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(28, 20);
    _trackingDuration = MathUtils.randomRange(2.0, 4.0);
    _trackingTimer = 0;
    _velocityX = 0;
    _rotorSpin = 0;
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size * 0.8, position: size * 0.1));
  }

  @override
  void updateObstacle(double dt) {
    _rotorSpin += dt * 20;
    if (_trackingTimer < _trackingDuration) {
      _trackingTimer += dt;
      final targetX = game.plane.position.x;
      final diff = targetX - position.x;
      _velocityX = MathUtils.lerp(_velocityX, diff * 1.5, 0.08);
      position.x = (position.x + _velocityX * dt).clamp(
        GameConfig.horizontalEdgeMargin,
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.fill;
    final ledPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;
    final armPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final w = size.x;
    final h = size.y;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6),
        const Radius.circular(4),
      ),
      bodyPaint,
    );
    // Arms
    canvas.drawLine(Offset(0, 0), Offset(w * 0.3, h * 0.3), armPaint);
    canvas.drawLine(Offset(w, 0), Offset(w * 0.7, h * 0.3), armPaint);
    canvas.drawLine(Offset(0, h), Offset(w * 0.3, h * 0.7), armPaint);
    canvas.drawLine(Offset(w, h), Offset(w * 0.7, h * 0.7), armPaint);
    // Rotors (spinning ellipses)
    final rotorPaint = Paint()
      ..color = const Color(0x88FFFFFF)
      ..style = PaintingStyle.fill;
    final rotorW = 6 + math.sin(_rotorSpin) * 2;
    canvas.drawOval(Rect.fromCenter(center: Offset(2, 2), width: rotorW, height: 3), rotorPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w - 2, 2), width: rotorW, height: 3), rotorPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(2, h - 2), width: rotorW, height: 3), rotorPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w - 2, h - 2), width: rotorW, height: 3), rotorPaint);
    // LED
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 3, ledPaint);
  }
}
