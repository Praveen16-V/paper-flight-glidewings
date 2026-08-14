// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 5. DroneObstacle — Armed Drone Elite (Smoke Puffs), Orbiting, Shield EMP Clash
// ─────────────────────────────────────────────────────────────────────────────

class DroneObstacle extends ObstacleComponent {
  DroneObstacle() : super(type: ObstacleType.drone);

  double _trackingDuration = 3.2;
  double _trackingTimer = 0;
  double _velocityX = 0;
  double _orbitAngle = 0;
  bool _isLockedOn = false;
  bool isArmed = false;
  bool isOrbiting = false;
  bool _shieldClashActive = false;
  bool _trafficLinked = false;

  @override
  Color get telegraphColor => isArmed ? const Color(0xFFFF1744) : const Color(0xFFFF5252);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(38, 28);
    _trackingDuration = rngRange(2.5, 4.2);
    _trackingTimer = 0;
    _velocityX = 0;
    _orbitAngle = rngRange(0, math.pi * 2);
    _isLockedOn = false;
    isArmed = rngRange(0, 1) < GameConfig.armedDroneEliteChance;
    isOrbiting = rngRange(0, 1) < GameConfig.orbitingDroneChance;
    _shieldClashActive = false;
    _trafficLinked = false;

    // Armed drones commit to the hunt: they track longer and close lateral
    // distance faster, which is what their targeting laser advertises.
    if (isArmed) {
      _trackingDuration *= 1.35;
    }

    _setupHitboxes();
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _trafficLinked = synergy == ObstacleSynergy.droneTrafficLink;
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(PolygonHitbox([
      Vector2(size.x * 0.5, 0),
      Vector2(size.x, size.y * 0.5),
      Vector2(size.x * 0.5, size.y),
      Vector2(0, size.y * 0.5),
    ]));
  }

  @override
  void updateObstacle(double dt) {
    _orbitAngle += dt * 2.4;

    // Shield EMP Interaction: Clash when close to Shield bubble
    if (gameRef.powerUpState.shieldActive) {
      final dist = (position - gameRef.plane.position).length;
      _shieldClashActive = dist < 80.0;
    } else {
      _shieldClashActive = false;
    }

    if (isOrbiting) {
      position.x += math.cos(_orbitAngle) * 55.0 * dt;
      return;
    }

    if (_trackingTimer < _trackingDuration) {
      _trackingTimer += dt;
      final targetX = gameRef.plane.position.x;
      final rawDiff = targetX - position.x;
      _isLockedOn = rawDiff.abs() < 40.0;
      final diff = rawDiff * dynamicMovementFactor;
      // Frame-rate independent pursuit: an exponential blend toward the
      // intercept velocity so 60 Hz and 120 Hz devices track identically.
      // Armed drones blend noticeably harder.
      final response = (isArmed ? 9.0 : 6.0) * dt;
      _velocityX =
          MathUtils.lerp(_velocityX, diff * 1.8, response.clamp(0.0, 1.0));
      position.x = (position.x + _velocityX * dt).clamp(
        GameConfig.horizontalEdgeMargin + 15,
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 15,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final tiltAngle = (_velocityX * 0.0022).clamp(-0.4, 0.4);

    _drawSearchlightBeam(canvas, w * 0.5, h * 0.5, tiltAngle);

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(tiltAngle);

    // Armed Drone: the red targeting beam only lights up once the drone has
    // actually locked onto the plane's column — an honest telegraph of its
    // faster, longer pursuit instead of a permanent decorative threat.
    if (isArmed && _isLockedOn) {
      final pulse = 0.55 + (math.sin(animTime * 14.0) * 0.5 + 0.5) * 0.45;
      final laser = Paint()
        ..color = const Color(0xFFFF1744).withOpacity(pulse)
        ..strokeWidth = 1.6;
      canvas.drawLine(const Offset(0, 5), const Offset(0, 160), laser);
    }

    // Drone chassis drop shadow, grounding the machine in 3D space.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 13), width: 32, height: 7),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Metallic arms with a cylindrical light sweep.
    final armPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF90A4AE), Color(0xFF263238), Color(0xFF0D1317)],
        stops: [0.0, .5, 1.0],
      ).createShader(const Rect.fromLTWH(-14, -12, 28, 24))
      ..strokeWidth = 3.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-13, -9), const Offset(13, 9), armPaint);
    canvas.drawLine(const Offset(-13, 9), const Offset(13, -9), armPaint);

    // Chassis body with a metallic gradient and a specular top edge.
    final bodyRect = const Rect.fromLTWH(-9, -7, 18, 14);
    final chassisLight = isArmed ? const Color(0xFFFF8A80) : const Color(0xFF90A4AE);
    final chassisColor = isArmed ? const Color(0xFFB71C1C) : const Color(0xFF37474F);
    final chassisDark = isArmed ? const Color(0xFF4E0000) : const Color(0xFF11181C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [chassisLight, chassisColor, chassisDark],
        ).createShader(bodyRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    // Sensor "eye" light on the front of the chassis.
    canvas.drawCircle(const Offset(0, 0), 1.7,
        Paint()..color = const Color(0x9900E5FF));
    canvas.drawCircle(const Offset(0, 0), .8, Paint()..color = Colors.white);

    // 4 Rotors
    for (final ro in [const Offset(-14, -10), const Offset(14, -10), const Offset(-14, 10), const Offset(14, 10)]) {
      _drawSpinningRotor(canvas, ro);
    }

    // EMP Shield Clash Arcs
    if (_shieldClashActive) {
      final empPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 2.0..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(-10, 0), const Offset(10, 0), empPaint);
      canvas.drawCircle(Offset.zero, 16, empPaint);
    }
    if (_trafficLinked) {
      final linkPaint = Paint()
        ..color = ObstacleSynergy.droneTrafficLink.color.withOpacity(.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, 20, linkPaint);
      canvas.drawLine(const Offset(0, -24), const Offset(0, -38), linkPaint);
    }

    canvas.restore();
    renderDestructibleIntegrity(canvas, centerX: w * .5, topY: -6);
    renderTelegraph(canvas);
  }

  void _drawSpinningRotor(Canvas canvas, Offset pos) {
    // Motor housing cylinder with a radial light sweep.
    canvas.drawCircle(
      pos,
      3.2,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: const [Color(0xFFCFD8DC), Color(0xFF455A64)],
        ).createShader(Rect.fromCircle(center: pos, radius: 3.2)),
    );
    // Motion-blurred rotor disc (semi-transparent, brighter toward the rim).
    final discRect = Rect.fromCenter(center: pos, width: 17, height: 6.5);
    canvas.drawOval(
      discRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCCE0E0E0), Color(0x40E0E0E0)],
        ).createShader(discRect),
    );
    // Trailing blade-tip arc for rotation feel.
    canvas.drawOval(
      Rect.fromCenter(center: pos, width: 19, height: 6),
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    // Hub specular catch.
    canvas.drawCircle(Offset(pos.dx - .6, pos.dy - .6), 1.0,
        Paint()..color = const Color(0x66FFFFFF));
  }

  void _drawSearchlightBeam(Canvas canvas, double cx, double cy, double tilt) {
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0x6600E5FF), const Color(0x0000E5FF)],
      ).createShader(Rect.fromLTWH(cx - 30, cy, 60, 160))
      ..style = PaintingStyle.fill;
    final beam = Path()..moveTo(cx - 4, cy + 4)..lineTo(cx - 35, cy + 160)..lineTo(cx + 35, cy + 160)..lineTo(cx + 4, cy + 4)..close();
    canvas.drawPath(beam, beamPaint);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. WindTurbineObstacle — 3 Rotating Aerodynamic Blades
// ─────────────────────────────────────────────────────────────────────────────

class WindTurbineObstacle extends ObstacleComponent {
  WindTurbineObstacle() : super(type: ObstacleType.windTurbine);

  double _bladeAngle = 0;
  double _rotSpeed = 1.4;
  double _bladeRadius = 65;
  bool _rotorWakeActive = false;

  @override
  Color get telegraphColor => const Color(0xFF00E676);

  @override
  void onActivate(double scrollSpeed) {
    _bladeRadius = rngRange(60, 78);
    size = Vector2(_bladeRadius * 2.2, _bladeRadius * 2.2 + 60);
    _bladeAngle = rngRange(0, math.pi * 2);
    _rotSpeed = rngRange(1.2, 1.9) * (rngBool() ? 1 : -1);
    _rotorWakeActive = false;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 14, position: Vector2(size.x * 0.5 - 14, _bladeRadius - 14)));
    add(RectangleHitbox(size: Vector2(16, 60), position: Vector2(size.x * 0.5 - 8, _bladeRadius)));
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _rotorWakeActive = synergy == ObstacleSynergy.rotorWake;
  }

  @override
  void updateObstacle(double dt) {
    final multiplier = _rotorWakeActive
        ? GameConfig.obstacleSynergyRotorSpeedMultiplier
        : 1.0;
    _bladeAngle += _rotSpeed * multiplier * dt;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = _bladeRadius;

    final mastRect = Rect.fromLTWH(cx - 12, cy, 24, size.y - cy);
    final mast = Path()..moveTo(cx - 7, cy)..lineTo(cx - 12, size.y)..lineTo(cx + 12, size.y)..lineTo(cx + 7, cy)..close();
    // Tapered concrete/steel tower: a sunlit left edge sinking into shadow.
    canvas.drawPath(
      mast,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFAFAFA), Color(0xFFCFD8DC), Color(0xFF90A4AE)],
          stops: [0.0, .6, 1.0],
        ).createShader(mastRect),
    );
    // Interior shadow band along the tower.
    canvas.drawPath(mast, Paint()..color = const Color(0x22FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    for (int i = 0; i < 3; i++) {
      final angle = _bladeAngle + i * (math.pi * 2 / 3);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      final bladeRect = Rect.fromLTWH(-6, 0, 12, _bladeRadius + 3);
      final blade = Path()..moveTo(-3, 0)..quadraticBezierTo(-6, _bladeRadius * 0.6, -2, _bladeRadius)..lineTo(0, _bladeRadius + 3)..lineTo(2, _bladeRadius)..quadraticBezierTo(4, _bladeRadius * 0.6, 3, 0)..close();
      // Blade gradient: lit leading edge fading to a shadowed trailing edge.
      canvas.drawPath(
        blade,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAFAFA), Color(0xFFE0E0E0), Color(0xFF90A4AE)],
            stops: [0.0, .55, 1.0],
          ).createShader(bladeRect),
      );
      // Aerodynamic crease down the blade centre.
      canvas.drawPath(
        blade,
        Paint()
          ..color = const Color(0x44000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      canvas.restore();
    }

    // Spinning hub with a radial metallic sheen and a centre bolt.
    canvas.drawCircle(
      Offset(cx, cy),
      8.0,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: const [Color(0xFFFFFFFF), Color(0xFFB0BEC5)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 8.0)),
    );
    canvas.drawCircle(Offset(cx, cy), 8.0,
        Paint()..color = const Color(0xFF90A4AE)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    canvas.drawCircle(Offset(cx, cy), 2.0, Paint()..color = const Color(0xFF455A64));
    if (_rotorWakeActive) {
      final wakePaint = Paint()
        ..color = ObstacleSynergy.rotorWake.color.withOpacity(.54)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: _bladeRadius * 2.8, height: _bladeRadius * 1.7),
        animTime * 4.0,
        math.pi * 1.45,
        false,
        wakePaint,
      );
    }
    renderTelegraph(canvas);
  }
}

