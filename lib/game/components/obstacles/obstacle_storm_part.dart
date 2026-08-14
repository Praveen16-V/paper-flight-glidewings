// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 15. LightningStrikeObstacle — Telegraph, Flash, Vertical Strike
// ─────────────────────────────────────────────────────────────────────────────

class LightningStrikeObstacle extends ObstacleComponent {
  LightningStrikeObstacle() : super(type: ObstacleType.lightningStrike);

  bool _struck = false;
  double _strikeTimer = 0;
  bool _stormCharged = false;

  @override
  Color get telegraphColor => const Color(0xFFFFF176);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(44, GameConfig.designHeight);
    _struck = false;
    _strikeTimer = 0;
    _stormCharged = false;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _stormCharged = synergy == ObstacleSynergy.stormCharge;
  }

  @override
  void updateObstacle(double dt) {
    if (!_struck && position.y >= -18) {
      _struck = true;
      final strikeWidth = _stormCharged ? 30.0 : 20.0;
      _strikeTimer = _stormCharged
          ? GameConfig.obstacleSynergyStormStrikeDuration
          : .34;
      add(RectangleHitbox(
        size: Vector2(strikeWidth, GameConfig.designHeight),
        position: Vector2((size.x - strikeWidth) * .5, 0),
      ));
      refreshHitboxCache();
    }
    if (_struck) {
      _strikeTimer -= dt;
      if (_strikeTimer <= 0) {
        _active = false;
        onRecycle?.call(this);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final x = size.x * .5;
    if (!_struck) {
      final warn = Paint()
        ..color = const Color(0x44FFF176)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), warn);
      renderTelegraph(canvas);
      return;
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = _stormCharged
          ? const Color(0x55FFF59D)
          : const Color(0x33FFFDE7),
    );

    // Broad corona flash behind the bolt.
    final corona = Paint()
      ..color = const Color(0x66FFF59D)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, size.y * .35), width: 70, height: 140), corona);

    // Main jagged channel with a secondary off-colour branch.
    final bolt = Path()..moveTo(x, 0);
    final branch = Path();
    var branchPlaced = false;
    for (var i = 0; i < 12; i++) {
      final y = (i + 1) * size.y / 12;
      final dx = i.isEven ? -10.0 : 10.0;
      bolt.lineTo(x + dx, y - 18);
      bolt.lineTo(x, y);
      // Split a couple of sub-arcs out of the channel for realism.
      if (!branchPlaced && i == 3) {
        branch
          ..moveTo(x + dx, y - 18)
          ..lineTo(x + dx + (dx < 0 ? -1 : 1) * 22, y - 8)
          ..lineTo(x + dx + (dx < 0 ? -1 : 1) * 10, y + 8)
          ..lineTo(x + dx + (dx < 0 ? -1 : 1) * 26, y + 20);
        branchPlaced = true;
      } else if (i == 8) {
        branch
          ..moveTo(x + dx, y - 18)
          ..lineTo(x - dx - 18, y - 4)
          ..lineTo(x - dx - 8, y + 12);
      }
    }

    final glow = Paint()
      ..color = const Color(0x99FFF176)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stormCharged ? 12 : 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final core = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bolt, glow);
    canvas.drawPath(bolt, core);
    // Branch arcs are thinner and dimmer, still catching the glow.
    canvas.drawPath(branch, Paint()
      ..color = const Color(0xAAFFF9C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 16. MeteorShowerObstacle — Atmosphere Impacts with Warning Shadows
// ─────────────────────────────────────────────────────────────────────────────

class MeteorShowerObstacle extends ObstacleComponent {
  MeteorShowerObstacle() : super(type: ObstacleType.meteorShower);

  final List<_Meteor> _meteors = [];

  @override
  Color get telegraphColor => const Color(0xFFFFAB91);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 300);
    _meteors.clear();
    removeAll(children.whereType<ShapeHitbox>().toList());
    for (var i = 0; i < 4; i++) {
      final meteor = _Meteor(
        x: rngRange(42, GameConfig.designWidth - 42),
        y: 35 + i * 63 + rngRange(-12, 12),
        radius: rngRange(9, 16),
        phase: rngRange(0, math.pi * 2),
      );
      _meteors.add(meteor);
      add(CircleHitbox(
        radius: meteor.radius,
        position: Vector2(meteor.x - meteor.radius, meteor.y - meteor.radius),
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    for (final meteor in _meteors) {
      final shadow = Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(meteor.x + 10, meteor.y + 24),
          width: meteor.radius * 2.8,
          height: meteor.radius * .8,
        ),
        shadow,
      );
      final trail = Paint()
        ..color = const Color(0x99FF7043)
        ..strokeWidth = meteor.radius * .72
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(meteor.x - meteor.radius * 2.2, meteor.y - meteor.radius * 2.5),
        Offset(meteor.x, meteor.y),
        trail,
      );
      // White-hot luminous tail core.
      canvas.drawLine(
        Offset(meteor.x - meteor.radius * 1.4, meteor.y - meteor.radius * 1.6),
        Offset(meteor.x, meteor.y),
        Paint()
          ..color = const Color(0x99FFE0B2)
          ..strokeWidth = meteor.radius * .3
          ..strokeCap = StrokeCap.round,
      );
      // Rock body with a lit top-left and a scorched dark underside.
      final rockRect = Rect.fromCircle(center: Offset(meteor.x, meteor.y), radius: meteor.radius);
      canvas.drawCircle(
        Offset(meteor.x, meteor.y),
        meteor.radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 1.0,
            colors: const [Color(0xFFBCAAA4), Color(0xFF5D4037), Color(0xFF21120B)],
            stops: const [0.0, .55, 1.0],
          ).createShader(rockRect),
      );
      // Molten glow cracks on the surface.
      canvas.drawCircle(
        Offset(meteor.x - meteor.radius * .22, meteor.y - meteor.radius * .25),
        meteor.radius * .35,
        Paint()..color = const Color(0xFFFFAB91),
      );
      canvas.drawCircle(
        Offset(meteor.x + meteor.radius * .2, meteor.y + meteor.radius * .15),
        meteor.radius * .18,
        Paint()..color = const Color(0x99FFD54F),
      );
    }
    renderTelegraph(canvas);
  }
}

class _Meteor {
  const _Meteor({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double phase;
}

// ─────────────────────────────────────────────────────────────────────────────
// 17. TornadoObstacle — Rotating Wind Column with Pull Force
// ─────────────────────────────────────────────────────────────────────────────

class TornadoObstacle extends ObstacleComponent {
  TornadoObstacle() : super(type: ObstacleType.tornado);

  static const double _pullRadius = 128;

  @override
  Color get telegraphColor => const Color(0xFFB3E5FC);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(92, 190);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 35, position: Vector2(11, 74)));
  }

  @override
  void updateObstacle(double dt) {
    final center = position + Vector2(0, size.y * .58);
    final plane = game.plane;
    final delta = center - plane.position;
    final distance = delta.length;
    if (distance > 1 && distance < _pullRadius) {
      final force = delta.normalized() *
          (GameConfig.maxWindForce * 2.0 * (1.0 - distance / _pullRadius) * dt);
      plane.applyTornadoPull(force);
    }
  }

  @override
  void render(Canvas canvas) {
    final centerX = size.x * .5;
    final swirl = Paint()
      ..color = const Color(0x88B3E5FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (var i = 0; i < 6; i++) {
      final y = 22 + i * 25.0;
      final width = 28 + i * 8.0;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(centerX + math.sin(animTime * 8 + i) * 7, y),
          width: width,
          height: 14,
        ),
        animTime * 5 + i * .65,
        math.pi * 1.5,
        false,
        swirl,
      );
    }
    // Condensed funnel core with a soft grey gradient and debris.
    final funnelRect = Rect.fromCenter(center: Offset(centerX, 104), width: 58, height: 142);
    canvas.drawOval(
      funnelRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99B3E5FC), Color(0xCC78909C), Color(0xCC455A64)],
          stops: const [0.0, .55, 1.0],
        ).createShader(funnelRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Rising debris specks inside the funnel.
    final debris = Paint()..color = const Color(0x88FFFFFF);
    for (var i = 0; i < 5; i++) {
      final dy = math.sin(animTime * 9 + i * 2.1) * 6;
      canvas.drawCircle(
        Offset(centerX - 14 + (i % 3) * 14, 84 + i * 20 + dy),
        1.1 + (i % 2),
        debris,
      );
    }
    renderTelegraph(canvas);
  }
}

