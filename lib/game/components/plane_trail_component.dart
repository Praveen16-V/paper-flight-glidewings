import 'dart:collection';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';

/// Soft fading wispy ribbon that trails behind the paper plane.
///
/// Samples the plane's absolute world position every [GameConfig.trailSampleInterval]
/// seconds and keeps the most recent [GameConfig.trailLength] samples.
///
/// Rendered as a series of line segments drawn behind the plane body.
/// Each segment fades from [GameConfig.trailHeadAlpha] at the head to
/// fully transparent at the tail. Stroke width tapers from
/// [GameConfig.trailHeadWidth] to [GameConfig.trailTailWidth].
///
/// The trail is a child of [PlaneComponent] — it is added first in [onLoad]
/// so Flame draws it before the plane body (children render before parent).
/// Because positions are stored in absolute (world) coordinates, the render
/// method temporarily transforms the canvas back to world space.
class PlaneTrailComponent extends Component
    with HasGameRef<PaperFlightGame> {
  PlaneTrailComponent({required this.plane});

  /// Reference to the parent plane for position sampling.
  final PositionComponent plane;

  final Queue<Vector2> _positions = Queue<Vector2>();
  double _sampleTimer = 0.0;

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    // Only record and render while the game is actively playing.
    if (gameRef.phase != GamePhase.playing) return;

    _sampleTimer += dt;
    if (_sampleTimer >= GameConfig.trailSampleInterval) {
      _sampleTimer = 0.0;
      // Capture absolute position so the trail stays fixed in world space
      // even as the parent component moves.
      _positions.addLast(plane.absolutePosition.clone());

      // Trim to the configured history length.
      while (_positions.length > GameConfig.trailLength) {
        _positions.removeFirst();
      }
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (_positions.length < 2) return;

    final positions = _positions.toList();
    final count = positions.length;

    // PlaneTrailComponent is a child of PlaneComponent. Flame has already
    // applied the parent's transform to the canvas before calling render():
    //   1. Translated to plane.position (top-left of bounding box)
    //   2. Rotated by plane.angle around the anchor (centre)
    //   3. Scaled by plane.scale
    //
    // Trail positions are stored in world (absolute) space. To draw them
    // correctly we must undo the parent transform so we render in world space.
    //
    // The parent PlaneComponent uses anchor = Anchor.center, so Flame
    // translates to (position - size/2) before rotating around size/2.
    // We reverse: un-rotate around (size.x/2, size.y/2), then un-translate.
    final parentPos = plane.position;   // top-left after anchor offset
    final parentAngle = plane.angle;
    final halfW = plane.size.x / 2;
    final halfH = plane.size.y / 2;

    canvas.save();

    // Undo parent rotation (rotate back around the sprite centre).
    canvas.translate(halfW, halfH);
    canvas.rotate(-parentAngle);
    canvas.translate(-halfW, -halfH);

    // Undo parent translation (move origin back to world 0,0).
    // Flame places the canvas origin at position - size/2 for center-anchored
    // components, so we translate by -(position - size/2).
    canvas.translate(-parentPos.x + halfW, -parentPos.y + halfH);

    for (int i = 1; i < count; i++) {
      // Head = most recent sample (last in queue = highest index).
      // headFraction: 0 at tail, 1 at head.
      final headFraction = i / (count - 1);

      final alpha = (GameConfig.trailHeadAlpha * headFraction).clamp(0.0, 1.0);
      final strokeWidth = MathUtils.lerp(
        GameConfig.trailTailWidth,
        GameConfig.trailHeadWidth,
        headFraction,
      );

      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, alpha)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Positions are already in world space — draw directly.
      canvas.drawLine(
        Offset(positions[i - 1].x, positions[i - 1].y),
        Offset(positions[i].x, positions[i].y),
        paint,
      );
    }

    canvas.restore();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Clears all stored trail positions. Call on reset and revive.
  void clear() {
    _positions.clear();
    _sampleTimer = 0.0;
  }
}
