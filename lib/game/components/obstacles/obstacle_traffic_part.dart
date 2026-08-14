// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 10. TrafficPlaneObstacle (NEW) — Oncoming Rogue Paper Airplanes
// ─────────────────────────────────────────────────────────────────────────────

class TrafficPlaneObstacle extends ObstacleComponent {
  TrafficPlaneObstacle() : super(type: ObstacleType.trafficPlane);

  double _lateralSpeed = 0;
  bool _droneDirected = false;

  @override
  Color get telegraphColor => const Color(0xFFFF9100);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(34, 34);
    _lateralSpeed = rngRange(-45, 45);
    _droneDirected = false;
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(PolygonHitbox([
      Vector2(size.x * 0.5, size.y),
      Vector2(size.x, 4),
      Vector2(size.x * 0.5, 12),
      Vector2(0, 4),
    ]));
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _droneDirected = synergy == ObstacleSynergy.droneTrafficLink;
  }

  @override
  void updateObstacle(double dt) {
    // A linked drone feeds a faster intercept vector to this traffic plane.
    final multiplier = _droneDirected
        ? GameConfig.obstacleSynergyTrafficSpeedMultiplier
        : 1.0;
    position.y += 65.0 * multiplier * dt;
    position.x += _lateralSpeed * multiplier * dt;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;

    // Upward-facing oncoming paper dart with a folded, lit-sheet look.
    final dart = Path()
      ..moveTo(cx, cy + 14)
      ..lineTo(cx + 14, cy - 12)
      ..lineTo(cx, cy - 6)
      ..lineTo(cx - 14, cy - 12)
      ..close();
    canvas.drawPath(
      dart,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFFE0B2), Color(0xFFFF7043), Color(0xFFC53F17)],
          stops: const [0.0, .55, 1.0],
        ).createShader(Rect.fromLTWH(cx - 14, cy - 12, 28, 26)),
    );
    // Centre fold crease + edge highlight for the folded-sheet silhouette.
    canvas.drawLine(Offset(cx, cy + 14), Offset(cx, cy - 8),
        Paint()..color = const Color(0x44FFFFFF)..strokeWidth = 1.2);
    canvas.drawPath(
      dart,
      Paint()
        ..color = const Color(0xFF8D3A12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Wingtip smoke contrails
    final contrail = Paint()
      ..color = (_droneDirected
              ? ObstacleSynergy.droneTrafficLink.color
              : Colors.white)
          .withOpacity(_droneDirected ? .72 : .40)
      ..strokeWidth = _droneDirected ? 1.8 : 1.2;
    canvas.drawLine(Offset(cx - 14, cy - 12), Offset(cx - 14, cy - 26), contrail);
    canvas.drawLine(Offset(cx + 14, cy - 12), Offset(cx + 14, cy - 26), contrail);
    if (_droneDirected) {
      canvas.drawCircle(
        Offset(cx, cy - 12),
        4.5,
        Paint()
          ..color = ObstacleSynergy.droneTrafficLink.color.withOpacity(.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. FireworksObstacle (NEW) — Ascending Firework Rocket & Popping Starbursts
// ─────────────────────────────────────────────────────────────────────────────

class FireworksObstacle extends ObstacleComponent {
  FireworksObstacle() : super(type: ObstacleType.fireworks);

  double _burstTimer = 0.8;
  bool _burst = false;

  @override
  Color get telegraphColor => const Color(0xFFFF4081);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(56, 56);
    _burstTimer = rngRange(0.6, 1.2);
    _burst = false;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 22, position: Vector2(6, 6)));
  }

  @override
  void updateObstacle(double dt) {
    if (!_burst) {
      _burstTimer -= dt;
      if (_burstTimer <= 0) _burst = true;
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;

    if (!_burst) {
      // Ascending rocket: cylindrical metal body with a lit nose cone.
      final bodyRect = Rect.fromCenter(center: Offset(cx, cy + 1), width: 6, height: 14);
      canvas.drawRect(
        bodyRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF8A80), Color(0xFFD32F2F), Color(0xFF7F0000)],
            stops: const [0.0, .55, 1.0],
          ).createShader(bodyRect),
      );
      canvas.drawRect(Rect.fromLTWH(cx - 3, cy + 1, 6, 1.4),
          Paint()..color = const Color(0x55FFFFFF));
      // Nose cone.
      final nose = Path()..moveTo(cx - 3, cy - 6)..lineTo(cx, cy - 11)..lineTo(cx + 3, cy - 6)..close();
      canvas.drawPath(nose, Paint()..color = const Color(0xFFFF5252));
      // Flame exhaust with layered glow.
      canvas.drawCircle(Offset(cx, cy + 10), 3, Paint()..color = const Color(0x88FFD54F));
      canvas.drawCircle(Offset(cx, cy + 11), 1.8, Paint()..color = const Color(0xFFFFF9C4));
    } else {
      // Popping multi-point starburst
      final burstPaint = Paint()..color = const Color(0xFFFF4081)..strokeWidth = 2.0;
      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(Offset(cx, cy), Offset(cx + math.cos(a) * 22, cy + math.sin(a) * 22), burstPaint);
      }
      canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = const Color(0xFFFFF9C4));
    }

    renderDestructibleIntegrity(canvas, centerX: cx, topY: 1);
    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 12. WeatherBalloonObstacle (NEW) — Satellite Cluster & Weather Balloon
// ─────────────────────────────────────────────────────────────────────────────

class WeatherBalloonObstacle extends ObstacleComponent {
  WeatherBalloonObstacle() : super(type: ObstacleType.weatherBalloon);

  @override
  Color get telegraphColor => const Color(0xFF00E5FF);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(64, 72);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 24, position: Vector2(8, 0)));
    add(RectangleHitbox(size: Vector2(28, 20), position: Vector2(18, 48)));
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    // Weather balloon dome: translucent latex with a lit top-left sheen.
    final domeRect = Rect.fromCircle(center: Offset(cx, 24), radius: 24);
    canvas.drawCircle(
      Offset(cx, 24),
      24,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.0,
          colors: const [Color(0xFFE1F5FE), Color(0xFF4DD0E1), Color(0xFF00838F)],
          stops: const [0.0, .55, 1.0],
        ).createShader(domeRect),
    );
    canvas.drawCircle(Offset(cx - 8, 15), 6, Paint()..color = const Color(0x40FFFFFF));
    canvas.drawCircle(Offset(cx, 24), 24,
        Paint()..color = const Color(0xFF00695C)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    // Vertical seam stripe.
    canvas.drawPath(
      Path()
        ..moveTo(cx - 2, 2)
        ..cubicTo(cx + 1, 12, cx + 1, 36, cx - 3, 46),
      Paint()..color = const Color(0x33000000)..strokeWidth = 1.0,
    );

    // Tether cables & satellite sensor box with a metallic gradient.
    canvas.drawLine(Offset(cx - 10, 48), Offset(cx - 8, 54), Paint()..color = const Color(0xFF78909C));
    canvas.drawLine(Offset(cx + 10, 48), Offset(cx + 8, 54), Paint()..color = const Color(0xFF78909C));
    final boxRect = Rect.fromLTWH(cx - 14, 54, 28, 16);
    canvas.drawRect(
      boxRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF90A4AE), Color(0xFF455A64), Color(0xFF1C2529)],
        ).createShader(boxRect),
    );
    canvas.drawRect(Rect.fromLTWH(cx - 14, 54, 28, 1.6),
        Paint()..color = const Color(0x55FFFFFF));
    canvas.drawCircle(Offset(cx, 62), 3,
        Paint()..color = const Color(0xFF00E5FF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    renderDestructibleIntegrity(canvas, centerX: cx, topY: 0);
    renderTelegraph(canvas);
  }
}

