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

    // Scroll downward with the world.
    position.y += game.scrollSpeed * dt;

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
        dist > GameConfig.nearMissDistance * 0.3) {
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
    _gapX = MathUtils.randomRange(
      GameConfig.horizontalEdgeMargin * 2,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin * 2 - _gapWidth,
    );
    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    // Left segment hitbox
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
    // Pole at left edge
    canvas.drawRect(Rect.fromLTWH(4, 0, 6, h), polePaint);
    // Pole at right edge
    canvas.drawRect(Rect.fromLTWH(w - 10, 0, 6, h), polePaint);
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

    final w = size.x;
    final h = size.y;
    final rightStart = _leftWidth + _gapWidth;

    // Left building
    canvas.drawRect(Rect.fromLTWH(0, 0, _leftWidth, h), buildingPaint);
    // Right building
    canvas.drawRect(
        Rect.fromLTWH(rightStart, 0, w - rightStart, h), buildingPaint);

    // Window dots on left building
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
      for (double y = 8.0; y < bh - winH - 4; y += rowGap) {
        // 60% chance each window is lit
        if ((x + y).toInt() % 5 != 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, winW, winH), paint);
        }
      }
    }
  }
}

/// Tree branch — hangs from the top or rises from the bottom.
class TreeBranchObstacle extends ObstacleComponent {
  TreeBranchObstacle() : super(type: ObstacleType.treeBranch);

  bool _fromTop = true;
  double _branchWidth = 60;

  @override
  void onActivate(double scrollSpeed) {
    _fromTop = MathUtils.randomRange(0, 1) > 0.5;
    _branchWidth = MathUtils.randomRange(50, 100);
    size = Vector2(_branchWidth, 24);
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

    // Branch stem
    canvas.drawRect(Rect.fromLTWH(w * 0.45, 0, w * 0.1, h), branchPaint);
    // Foliage cluster
    canvas.drawOval(Rect.fromLTWH(0, _fromTop ? 0 : h * 0.3, w, h * 0.7),
        paint);
  }
}

/// Bird — patrols a horizontal lane, swooping left-right.
class BirdObstacle extends ObstacleComponent {
  BirdObstacle() : super(type: ObstacleType.bird);

  double _patrolAmplitude = 60;
  double _patrolFreq = 1.5;
  double _patrolPhase = 0;
  double _spawnX = 0;

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(30, 18);
    _spawnX = position.x;
    _patrolAmplitude = MathUtils.randomRange(40, 90);
    _patrolFreq = MathUtils.randomRange(1.0, 2.5);
    _patrolPhase = MathUtils.randomRange(0, 6.28);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size * 0.7, position: size * 0.15));
  }

  @override
  void updateObstacle(double dt) {
    _patrolPhase += _patrolFreq * dt;
    position.x = (_spawnX + _patrolAmplitude * sin(_patrolPhase))
        .clamp(GameConfig.horizontalEdgeMargin,
            GameConfig.designWidth - GameConfig.horizontalEdgeMargin);
  }

  double sin(double x) => (x - x.floor() * 2 > 1)
      ? -(x.floor().isEven ? 1 : -1) * (x % 1)
      : (x.floor().isEven ? 1 : -1) * (x % 1);

  @override
  void render(Canvas canvas) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..style = PaintingStyle.fill;

    final w = size.x;
    final h = size.y;

    // Simple bird silhouette — oval body, two wing arcs
    canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.4, h * 0.6),
        bodyPaint);
    // Left wing
    final path = Path()
      ..moveTo(w * 0.3, h * 0.4)
      ..quadraticBezierTo(0, 0, 0, h * 0.3)
      ..lineTo(w * 0.3, h * 0.5);
    canvas.drawPath(path, bodyPaint);
    // Right wing
    final path2 = Path()
      ..moveTo(w * 0.7, h * 0.4)
      ..quadraticBezierTo(w, 0, w, h * 0.3)
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

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(28, 20);
    _trackingDuration = MathUtils.randomRange(2.0, 4.0);
    _trackingTimer = 0;
    _velocityX = 0;
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size * 0.8, position: size * 0.1));
  }

  @override
  void updateObstacle(double dt) {
    if (_trackingTimer < _trackingDuration) {
      _trackingTimer += dt;
      // Track player X
      final targetX = gameRef.plane.position.x;
      final diff = targetX - position.x;
      _velocityX = MathUtils.lerp(_velocityX, diff * 1.5, 0.08);
      position.x =
          (position.x + _velocityX * dt).clamp(GameConfig.horizontalEdgeMargin,
              GameConfig.designWidth - GameConfig.horizontalEdgeMargin);
    }
    // After tracking, drone continues straight down at current X.
  }

  @override
  void render(Canvas canvas) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.fill;
    final ledPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;

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
    final armPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 0), Offset(w * 0.3, h * 0.3), armPaint);
    canvas.drawLine(Offset(w, 0), Offset(w * 0.7, h * 0.3), armPaint);
    canvas.drawLine(Offset(0, h), Offset(w * 0.3, h * 0.7), armPaint);
    canvas.drawLine(Offset(w, h), Offset(w * 0.7, h * 0.7), armPaint);
    // LED
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 3, ledPaint);
  }
}
