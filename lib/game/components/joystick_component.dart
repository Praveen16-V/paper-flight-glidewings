import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../systems/input_manager.dart';

/// Floating virtual joystick visual.
///
/// Purely cosmetic — all input logic lives in [InputManager]. This component
/// reads the joystick readouts from the input manager each frame and draws the
/// base ring + knob on top of the world, in design (world) coordinates, so the
/// stick always appears exactly under the thumb.
///
/// Behaviour:
///   • The stick fades in where the thumb lands and fades out on release.
///   • The knob tracks the (radius-clamped) stick deflection.
///   • Only visible while the [ControlScheme.joystick] scheme is active.
class JoystickComponent extends PositionComponent {
  JoystickComponent({required this.inputManager})
      : super(size: Vector2(GameConfig.designWidth, GameConfig.designHeight));

  final InputManager inputManager;

  /// Smooth fade amount — 0 = hidden, 1 = fully visible.
  double _alpha = 0.0;

  /// Knob position carried across frames so the fade-out keeps the last spot.
  Offset _knobCenter = Offset.zero;

  // ── Palette ───────────────────────────────────────────────────────────────

  static const Color _accent = Color(0xFFF5A623); // accent gold
  static const Color _ring = Color(0xFFFFFFFF);

  @override
  void update(double dt) {
    // Never show unless the joystick scheme is active.
    if (inputManager.currentScheme != ControlScheme.joystick) {
      _alpha = 0.0;
      return;
    }

    final target = inputManager.joystickActive ? 1.0 : 0.0;
    // Fade in fast, ease out a touch slower so release feels soft.
    final rate = target > _alpha ? 14.0 : 5.0;
    _alpha += (target - _alpha) * (rate * dt).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    if (_alpha <= 0.01) return;
    if (inputManager.currentScheme != ControlScheme.joystick) return;

    final base = inputManager.joystickBasePosition.toOffset();
    final knobOffset = inputManager.joystickKnobOffset.toOffset();
    _knobCenter = base + knobOffset;

    _drawBaseRing(canvas, base);
    _drawDirectionTicks(canvas, base);
    _drawKnob(canvas);
  }

  // ── Base ring ─────────────────────────────────────────────────────────────

  void _drawBaseRing(Canvas canvas, Offset center) {
    final radius = GameConfig.joystickRadius;

    // Soft filled disc so the stick reads against any background.
    final fill = Paint()
      ..color = const Color(0xFF000000).withOpacity(0.22 * _alpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fill);

    // Gentle glow when active.
    if (_alpha > 0.5) {
      final glow = Paint()
        ..color = _accent.withOpacity(0.18 * _alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, radius + 4, glow);
    }

    // Outer ring.
    final ring = Paint()
      ..color = _ring.withOpacity(0.45 * _alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius, ring);

    // Inner hint ring — marks the steering travel circle.
    final inner = Paint()
      ..color = _ring.withOpacity(0.14 * _alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius * 0.62, inner);
  }

  // ── Direction ticks ───────────────────────────────────────────────────────

  void _drawDirectionTicks(Canvas canvas, Offset center) {
    final radius = GameConfig.joystickRadius;
    final tick = Paint()
      ..color = _ring.withOpacity(0.55 * _alpha)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (final angle in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + dir * (radius - 11),
        center + dir * (radius - 4),
        tick,
      );
    }
  }

  // ── Knob ──────────────────────────────────────────────────────────────────

  void _drawKnob(Canvas canvas) {
    final radius = GameConfig.joystickRadius * 0.42;

    // Soft shadow under the knob.
    final shadow = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(_knobCenter + const Offset(0, 1.5), radius, shadow);

    // Accent glow.
    final glow = Paint()
      ..color = _accent.withOpacity(0.35 * _alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawCircle(_knobCenter, radius + 3, glow);

    // Knob body.
    final body = Paint()
      ..color = _accent.withOpacity(0.95 * _alpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(_knobCenter, radius, body);

    // Rim.
    final rim = Paint()
      ..color = _ring.withOpacity(0.75 * _alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(_knobCenter, radius, rim);

    // Glossy highlight.
    final gloss = Paint()..color = const Color(0x77FFFFFF);
    canvas.drawCircle(
      _knobCenter - Offset(radius * 0.28, radius * 0.32),
      radius * 0.30,
      gloss,
    );
  }
}
