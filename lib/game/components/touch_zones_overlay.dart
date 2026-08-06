import 'dart:ui';

import 'package:flame/components.dart' hide JoystickComponent;

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../systems/input_manager.dart';

/// Subtle on-screen visual for the [ControlScheme.touchZones] control scheme.
///
/// Purely cosmetic — all input logic lives in [InputManager]. Draws faint
/// left/right chevron guides at the screen edges plus a soft highlight on the
/// half the player is currently touching, so tapping "left half" vs
/// "right half" reads naturally on screen.
///
/// Behaviour:
///   • Only visible while the [ControlScheme.touchZones] scheme is active.
///   • When [visible] is false the guides fade out and are never drawn — tap
///     input still works, so players can steer blind for a cleaner view.
class TouchZonesOverlay extends PositionComponent {
  TouchZonesOverlay({required this.inputManager})
      : super(size: Vector2(GameConfig.designWidth, GameConfig.designHeight));

  final InputManager inputManager;

  /// Whether the guides may be drawn. Tied to the "show on-screen controls"
  /// setting.
  bool visible = true;

  /// Smooth fade amount — 0 = hidden, 1 = fully visible.
  double _alpha = 0.0;

  static const Color _accent = Color(0xFFF5A623); // accent gold
  static const Color _guide = Color(0xFFFFFFFF);

  @override
  void update(double dt) {
    final target = (!visible ||
            inputManager.currentScheme != ControlScheme.touchZones)
        ? 0.0
        : 1.0;
    // Fade in fast, ease out a touch slower so hiding feels soft.
    final rate = target > _alpha ? 10.0 : 5.0;
    _alpha += (target - _alpha) * (rate * dt).clamp(0.0, 1.0);
    if (_alpha <= 0.01) _alpha = 0.0;
  }

  @override
  void render(Canvas canvas) {
    if (_alpha <= 0.01) return;

    _drawCenterDivider(canvas);
    _drawSideGuide(canvas, left: true);
    _drawSideGuide(canvas, left: false);
  }

  // ── Center divider ────────────────────────────────────────────────────────

  /// Dashed vertical line marking the left/right boundary, so the zones read
  /// as "this half vs that half" instead of a hidden split.
  void _drawCenterDivider(Canvas canvas) {
    final midX = size.x / 2;
    final paint = Paint()
      ..color = _guide.withOpacity(0.10 * _alpha)
      ..strokeWidth = 1.5;

    const dash = 10.0;
    const gap = 9.0;
    double y = size.y * 0.22;
    while (y < size.y * 0.78) {
      canvas.drawLine(Offset(midX, y), Offset(midX, y + dash), paint);
      y += dash + gap;
    }
  }

  // ── Side guides ───────────────────────────────────────────────────────────

  void _drawSideGuide(Canvas canvas, {required bool left}) {
    final active = left ? inputManager.touchZoneLeft : inputManager.touchZoneRight;

    // Soft tint across the active half so the player sees which zone fired.
    if (active) {
      final rect = left
          ? Rect.fromLTRB(0, 0, size.x / 2, size.y)
          : Rect.fromLTRB(size.x / 2, 0, size.x, size.y);
      canvas.drawRect(rect, Paint()..color = _accent.withOpacity(0.10 * _alpha));
    }

    // Chevron guide at the vertical centre of the play area.
    final cx = left ? 24.0 : size.x - 24.0;
    final cy = size.y * 0.5;
    final s = 13.0; // chevron size
    final chevron = Paint()
      ..color = (active ? _accent : _guide).withOpacity((active ? 0.9 : 0.25) * _alpha)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (left) {
      path
        ..moveTo(cx + s, cy - s)
        ..lineTo(cx - s * 0.25, cy)
        ..lineTo(cx + s, cy + s);
    } else {
      path
        ..moveTo(cx - s, cy - s)
        ..lineTo(cx + s * 0.25, cy)
        ..lineTo(cx - s, cy + s);
    }
    canvas.drawPath(path, chevron);
  }
}
