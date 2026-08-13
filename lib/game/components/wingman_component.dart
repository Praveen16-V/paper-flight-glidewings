import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../core/constants/game_config.dart';

/// A non-colliding friendly paper plane that follows the player's formation.
///
/// Wingmen deliberately use delayed steering rather than snapping to their
/// offsets: steady pilots keep their squad close, while abrupt dives or
/// lateral changes can break the formation bonus until everyone regroups.
class WingmanComponent extends PositionComponent {
  WingmanComponent({
    required this.formationOffset,
    required this.tint,
    required int seed,
  })  : _rng = math.Random(seed),
        super(
          size: Vector2(36, 24),
          anchor: Anchor.center,
        );

  final Vector2 formationOffset;
  final Color tint;
  final math.Random _rng;

  bool visible = false;
  bool _active = false;
  bool get isActive => _active;

  bool _formationLocked = false;
  double _time = 0;
  double _distanceToLeader = double.infinity;
  double get distanceToLeader => _distanceToLeader;

  /// Starts beside [leaderPosition] at the appropriate formation offset.
  void activate(Vector2 leaderPosition) {
    _active = true;
    visible = true;
    _formationLocked = false;
    _time = _rng.nextDouble() * math.pi * 2;
    position = leaderPosition + formationOffset;
    angle = 0;
    _distanceToLeader = formationOffset.length;
  }

  void deactivate() {
    _active = false;
    visible = false;
    _formationLocked = false;
    _distanceToLeader = double.infinity;
  }

  /// Smoothly follows a delayed formation point around [leaderPosition].
  void followLeader(Vector2 leaderPosition, double dt) {
    if (!_active) return;

    _time += dt;
    final desired = leaderPosition + formationOffset;
    final blend =
        (1.0 - math.exp(-GameConfig.wingmanFollowResponsePerSecond * dt))
            .clamp(0.0, 1.0)
            .toDouble();
    final previous = position.clone();
    position += (desired - position) * blend;
    _distanceToLeader = (position - leaderPosition).length;

    final lateralVelocity = dt <= 0 ? 0.0 : (position.x - previous.x) / dt;
    final targetBank = (lateralVelocity * .0011).clamp(-.18, .18).toDouble();
    angle += (targetBank - angle) * (7.0 * dt).clamp(0.0, 1.0).toDouble();
  }

  void setFormationLocked(bool value) => _formationLocked = value;

  bool isNearLeader(Vector2 leaderPosition) =>
      _active && (position - leaderPosition).length <=
          GameConfig.wingmanFormationRadius;

  @override
  void render(Canvas canvas) {
    if (!_active || !visible) return;

    final w = size.x;
    final h = size.y;
    final center = Offset(w / 2, h / 2);
    final pulse = .72 + math.sin(_time * 4.0) * .16;

    if (_formationLocked) {
      final aura = Paint()
        ..color = Color.fromRGBO(128, 222, 234, .22 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(center, w * .72, aura);
    }

    // A compact folded dart silhouette, tinted differently for each wingman.
    final upperWing = Path()
      ..moveTo(w + 2, h / 2)
      ..lineTo(w * .35, h / 2)
      ..lineTo(0, h * .10)
      ..close();
    final lowerWing = Path()
      ..moveTo(w + 2, h / 2)
      ..lineTo(w * .35, h / 2)
      ..lineTo(0, h * .90)
      ..close();
    final body = Path()
      ..moveTo(w + 2, h / 2)
      ..lineTo(w * .28, h / 2 - 2)
      ..lineTo(0, h / 2)
      ..lineTo(w * .28, h / 2 + 2)
      ..close();

    final upperPaint = Paint()
      ..color = Color.lerp(tint, const Color(0xFFFFFFFF), .26)!
      ..style = PaintingStyle.fill;
    final lowerPaint = Paint()
      ..color = Color.lerp(tint, const Color(0xFF17232D), .24)!
      ..style = PaintingStyle.fill;
    final bodyPaint = Paint()
      ..color = tint
      ..style = PaintingStyle.fill;
    canvas.drawPath(upperWing, upperPaint);
    canvas.drawPath(lowerWing, lowerPaint);
    canvas.drawPath(body, bodyPaint);

    final crease = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75;
    canvas.drawLine(Offset(w * .12, h / 2), Offset(w * .86, h / 2), crease);

    // Formation light and a brief dotted paper trail make followers legible
    // without letting them read as dangerous traffic.
    final light = Paint()
      ..color = _formationLocked
          ? const Color(0xFFB9F6CA)
          : const Color(0xFFE1F5FE)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * .12, h / 2), 1.7 + pulse * .55, light);
    final trail = Paint()
      ..color = Color.fromRGBO(225, 245, 254, .24 * pulse)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(-5.0 - i * 5.0, h / 2 + math.sin(_time * 5 + i) * 1.5),
        1.0 - i * .18,
        trail,
      );
    }

    super.render(canvas);
  }
}
