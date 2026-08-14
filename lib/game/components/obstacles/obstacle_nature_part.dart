// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 3. TreeBranchObstacle — Multi-Branch Thicket Elite, Hanging Swing
// ─────────────────────────────────────────────────────────────────────────────

class TreeBranchObstacle extends ObstacleComponent {
  TreeBranchObstacle() : super(type: ObstacleType.treeBranch);

  bool _fromLeft = true;
  double _branchWidth = 90;
  double _swayPhase = 0;
  bool isThicket = false;
  final List<_LeafParticle> _fallingLeaves = [];

  @override
  Color get telegraphColor => const Color(0xFF66BB6A);

  @override
  void onActivate(double scrollSpeed) {
    _fromLeft = script?.fromLeft ?? rngBool();
    _branchWidth = rngRange(75, 125);
    isThicket = rngRange(0, 1) < GameConfig.thicketBranchEliteChance;
    size = Vector2(isThicket ? GameConfig.designWidth : _branchWidth, 54);
    _swayPhase = rngRange(0, math.pi * 2);
    _fallingLeaves.clear();

    if (isThicket) {
      position.x = 0;
    } else if (_fromLeft) {
      position.x = 0;
    } else {
      position.x = GameConfig.designWidth - _branchWidth;
    }

    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    if (isThicket) {
      add(RectangleHitbox(size: Vector2(110, 42), position: Vector2(0, 6)));
      add(RectangleHitbox(
        size: Vector2(110, 42),
        position: Vector2(GameConfig.designWidth - 110, 6),
      ));
    } else {
      add(RectangleHitbox(
        size: Vector2(size.x * 0.85, size.y * 0.7),
        position: Vector2(_fromLeft ? 0 : size.x * 0.15, size.y * 0.15),
      ));
    }
  }

  @override
  void updateObstacle(double dt) {
    _swayPhase += dt * 3.0;

    if (rngRange(0, 1) < dt * 1.8) {
      final startX = _fromLeft
          ? rngRange(size.x * 0.4, size.x)
          : rngRange(0, size.x * 0.6);
      _fallingLeaves.add(_LeafParticle(
        x: startX,
        y: size.y * 0.5,
        vx: rngRange(-15, 15),
        vy: rngRange(30, 60),
        color: const Color(0xFF81C784),
        angle: rngRange(0, math.pi * 2),
      ));
    }

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

    if (isThicket) {
      _drawSingleBranch(canvas, 120, h, sway, true);
      _drawSingleBranch(canvas, 120, h, -sway, false);
    } else {
      _drawSingleBranch(canvas, w, h, sway, _fromLeft);
    }

    // Render falling leaves
    final leafPaint = Paint()..style = PaintingStyle.fill;
    for (final leaf in _fallingLeaves) {
      leafPaint.color = leaf.color.withOpacity(leaf.life.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(leaf.x, leaf.y);
      canvas.rotate(leaf.angle);
      canvas.drawOval(const Rect.fromLTWH(-3, -1.8, 6, 3.6), leafPaint);
      canvas.restore();
    }

    renderTelegraph(canvas);
  }

  void _drawSingleBranch(Canvas canvas, double bw, double bh, double sway, bool fromLeft) {
    canvas.save();
    if (fromLeft) {
      canvas.translate(0, bh * 0.5);
      canvas.rotate(sway * 0.015);
      canvas.translate(0, -bh * 0.5);
    } else {
      canvas.translate(size.x, bh * 0.5);
      canvas.rotate(-sway * 0.015);
      canvas.translate(-size.x, -bh * 0.5);
    }

    final branchPath = Path();
    if (fromLeft) {
      branchPath.moveTo(0, bh * 0.32);
      branchPath.quadraticBezierTo(bw * 0.4, bh * 0.38, bw * 0.8, bh * 0.5);
      branchPath.lineTo(bw * 0.86, bh * 0.62);
      branchPath.quadraticBezierTo(bw * 0.4, bh * 0.68, 0, bh * 0.78);
    } else {
      final rightX = size.x;
      branchPath.moveTo(rightX, bh * 0.32);
      branchPath.quadraticBezierTo(rightX - bw * 0.4, bh * 0.38, rightX - bw * 0.8, bh * 0.5);
      branchPath.lineTo(rightX - bw * 0.86, bh * 0.62);
      branchPath.quadraticBezierTo(rightX - bw * 0.4, bh * 0.68, rightX, bh * 0.78);
    }
    branchPath.close();

    final bounds = branchPath.getBounds();
    // Under-shadow offset adds physical thickness beneath the branch.
    canvas.drawPath(branchPath, Paint()..color = const Color(0x22000000));
    // Cylindrical wood gradient: sunlit crest sinking into a shadowed underside.
    canvas.drawPath(
      branchPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF8D6E63),
            Color(0xFF5D4037),
            Color(0xFF3E2723),
          ],
          stops: const [0.0, .55, 1.0],
        ).createShader(bounds),
    );
    // Specular ridge along the branch crest.
    canvas.drawPath(
      branchPath,
      Paint()
        ..color = const Color(0x30FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    // Bark grain lines following the limb.
    final bark = Paint()
      ..color = const Color(0x333E2723)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final fx = (i + 1) * bw / 5.0;
      final by = bh * (0.44 + 0.05 * math.sin(i * 2.4 + _swayPhase * 0.3));
      canvas.drawLine(Offset(fx - 6, by), Offset(fx + 6, by + 2), bark);
    }

    _drawFoliageClusters(canvas, bw, bh, fromLeft);

    // Environmental Storytelling: Hanging Wooden Rope Swing
    if (!isThicket && bw > 85) {
      _drawHangingSwing(canvas, fromLeft ? bw * 0.65 : size.x - bw * 0.65, bh * 0.55, sway);
    }

    canvas.restore();
  }

  void _drawFoliageClusters(Canvas canvas, double bw, double bh, bool fromLeft) {
    final clusterCenters = fromLeft
        ? [Offset(bw * 0.35, bh * 0.35), Offset(bw * 0.62, bh * 0.28), Offset(bw * 0.84, bh * 0.5)]
        : [Offset(size.x - bw * 0.35, bh * 0.35), Offset(size.x - bw * 0.62, bh * 0.28), Offset(size.x - bw * 0.84, bh * 0.5)];

    // Deep canopy shadows behind each tuft add volumetric depth.
    final shadowPaint = Paint()..color = const Color(0x55082B10);
    for (int i = 0; i < clusterCenters.length; i++) {
      final c = clusterCenters[i];
      final r = 15.0 + (i % 2) * 5.0;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy + 3), width: r * 2.3, height: r * 1.7),
        shadowPaint,
      );
    }

    for (int i = 0; i < clusterCenters.length; i++) {
      final c = clusterCenters[i];
      final r = 15.0 + (i % 2) * 5.0;

      // Dark body gives each tuft a rounded base mass.
      final bodyRect = Rect.fromCenter(center: c, width: r * 2.2, height: r * 1.7);
      canvas.drawOval(bodyRect, Paint()..color = const Color(0xFF2E7D32));

      // Sunlit cap via a radial gradient (bright top-left, fading out).
      final capRect = Rect.fromCenter(center: Offset(c.dx, c.dy - 2), width: r * 1.7, height: r * 1.3);
      canvas.drawOval(
        capRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 0.9,
            colors: const [Color(0xFFA5D6A7), Color(0xFF4CAF50), Color(0x004CAF50)],
            stops: const [0.0, .6, 1.0],
          ).createShader(capRect),
      );

      // Individual leaf highlights along the lit rim.
      final leafPaint = Paint()..color = const Color(0x99A5D6A7);
      for (var k = 0; k < 3; k++) {
        final a = -1.4 + k * 0.6;
        final lx = c.dx + math.cos(a) * r * 0.55;
        final ly = c.dy - 2 + math.sin(a) * r * 0.4;
        canvas.drawOval(Rect.fromCenter(center: Offset(lx, ly), width: 5, height: 3), leafPaint);
      }
    }
  }

  void _drawHangingSwing(Canvas canvas, double cx, double cy, double sway) {
    final rope = Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 1.0;
    final seat = Paint()..color = const Color(0xFF4E342E)..style = PaintingStyle.fill;

    final swingX = cx + math.sin(_swayPhase * 0.8) * 4.0;
    canvas.drawLine(Offset(cx - 3, cy), Offset(swingX - 3, cy + 16), rope);
    canvas.drawLine(Offset(cx + 3, cy), Offset(swingX + 3, cy + 16), rope);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(swingX, cy + 17), width: 10, height: 2.5), const Radius.circular(1)), seat);
  }
}

class _LeafParticle {
  _LeafParticle({required this.x, required this.y, required this.vx, required this.vy, required this.color, required this.angle});
  double x, y, vx, vy, angle;
  Color color;
  double life = 1.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. BirdObstacle — Polygon Hitbox, Golden Bird Elite, V-Flocking, Ghost Scare
// ─────────────────────────────────────────────────────────────────────────────

class BirdObstacle extends ObstacleComponent {
  BirdObstacle() : super(type: ObstacleType.bird);

  double _patrolAmplitude = 75;
  double _patrolFreq = 1.8;
  double _patrolPhase = 0;
  double _spawnX = 0;
  double _velocityX = 0;
  double _wingFlapPhase = 0;
  int _birdSpecies = 0;
  bool isGolden = false;
  bool isFlock = false;
  bool _isScared = false;
  bool _rotorWakeActive = false;

  @override
  Color get telegraphColor => isGolden ? const Color(0xFFFFD700) : const Color(0xFF42A5F5);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(36, 26);
    _spawnX = position.x;
    _patrolAmplitude = script?.driftAmp ?? rngRange(55, 110);
    _patrolFreq = script?.driftFreq ?? rngRange(1.4, 2.6);
    _patrolPhase = rngRange(0, math.pi * 2);
    _wingFlapPhase = rngRange(0, math.pi * 2);
    _birdSpecies = rngInt(0, 2);
    isGolden = rngRange(0, 1) < GameConfig.goldenBirdEliteChance;
    isFlock = rngRange(0, 1) < GameConfig.birdMiniFlockChance;
    _isScared = false;
    _rotorWakeActive = false;
    _velocityX = 0;

    _setupHitboxes();
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _rotorWakeActive = synergy == ObstacleSynergy.rotorWake;
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    // Refined polygon hitbox for the lead avian diamond body.
    add(PolygonHitbox([
      Vector2(size.x * 0.5, 0),
      Vector2(size.x * 0.9, size.y * 0.5),
      Vector2(size.x * 0.5, size.y),
      Vector2(size.x * 0.1, size.y * 0.5),
    ]));

    // A mini-flock draws three birds — give the two wingmen real hitboxes at
    // exactly the offsets render() uses, so what you see is what can hit you.
    if (isFlock) {
      for (final dx in const [-20.0, 20.0]) {
        add(
          CircleHitbox(
            radius: 7.5,
            position:
                Vector2(size.x * 0.5 + dx - 7.5, size.y * 0.5 + 14 - 7.5),
          ),
        );
      }
    }
  }

  @override
  void updateObstacle(double dt) {
    final wakeMultiplier = _rotorWakeActive
        ? GameConfig.obstacleSynergyRotorSpeedMultiplier
        : 1.0;
    _patrolPhase += _patrolFreq * wakeMultiplier * dt;
    _wingFlapPhase += dt * (isGolden ? 12.0 : 9.0) * wakeMultiplier;

    // Ghost Interaction: Scared away when Ghost plane is near!
    if (gameRef.powerUpState.ghostActive) {
      final dist = (position - gameRef.plane.position).length;
      if (dist < 130) _isScared = true;
    }

    if (_isScared) {
      position.x += (_velocityX.isNegative ? -240.0 : 240.0) * dt;
      position.y -= 120.0 * dt;
      return;
    }

    final prevX = position.x;
    final targetX = _spawnX +
        _patrolAmplitude *
            (_rotorWakeActive ? 1.25 : 1.0) *
            dynamicMovementFactor *
            math.sin(_patrolPhase);
    position.x = targetX.clamp(
      GameConfig.horizontalEdgeMargin + 10,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 10,
    );
    _velocityX = (position.x - prevX) / math.max(0.001, dt);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final bankAngle = (_velocityX * 0.0018).clamp(-0.45, 0.45);

    if (_rotorWakeActive) {
      final wake = Paint()
        ..color = ObstacleSynergy.rotorWake.color.withOpacity(.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * .5, h * .5), width: w * 1.7, height: h * 1.5),
        animTime * 5.0,
        math.pi * 1.35,
        false,
        wake,
      );
    }

    if (isFlock) {
      // 3 Birds in aerodynamic V-Formation
      _drawSingleBird(canvas, w * 0.5, h * 0.5, bankAngle, isLead: true);
      _drawSingleBird(canvas, w * 0.5 - 20, h * 0.5 + 14, bankAngle, isLead: false);
      _drawSingleBird(canvas, w * 0.5 + 20, h * 0.5 + 14, bankAngle, isLead: false);
    } else {
      _drawSingleBird(canvas, w * 0.5, h * 0.5, bankAngle, isLead: true);
    }

    renderTelegraph(canvas);
  }

  void _drawSingleBird(Canvas canvas, double cx, double cy, double bank, {required bool isLead}) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(bank);

    final flapAmount = math.sin(_wingFlapPhase + (isLead ? 0 : 0.8));

    // Per-species 3D palette: a lit base, its shadow, and a specular highlight.
    final Color bodyBase;
    final Color bodyShadow;
    final Color wingHighlight;
    if (isGolden) {
      bodyBase = const Color(0xFFFFC107);
      bodyShadow = const Color(0xFFB8860B);
      wingHighlight = const Color(0xFFFFF9C4);
    } else if (_birdSpecies == 1) {
      bodyBase = const Color(0xFFFF8F00);
      bodyShadow = const Color(0xFFC75100);
      wingHighlight = const Color(0xFFFFE082);
    } else {
      bodyBase = const Color(0xFF78909C);
      bodyShadow = const Color(0xFF37474F);
      wingHighlight = const Color(0xFFCFD8DC);
    }

    // Wings: lit upper surface, shaded underside, drawn behind the body.
    final wingY = flapAmount * 8.0;
    final wingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [wingHighlight, bodyBase, bodyShadow],
        stops: const [0.0, .55, 1.0],
      ).createShader(Rect.fromLTWH(-20, wingY - 10, 40, 20));
    final leftWing = Path()..moveTo(-4, 0)..quadraticBezierTo(-10, wingY - 6, -18, wingY - 2)..lineTo(-15, wingY + 4)..lineTo(-3, 3)..close();
    final rightWing = Path()..moveTo(4, 0)..quadraticBezierTo(10, wingY - 6, 18, wingY - 2)..lineTo(15, wingY + 4)..lineTo(3, 3)..close();
    canvas.drawPath(leftWing, wingPaint);
    canvas.drawPath(rightWing, wingPaint);

    // Feather separation lines on the wings.
    final feather = Paint()
      ..color = bodyShadow.withOpacity(.5)
      ..strokeWidth = .8;
    canvas.drawLine(Offset(-6, wingY + 1), Offset(-14, wingY + 3), feather);
    canvas.drawLine(Offset(6, wingY + 1), Offset(14, wingY + 3), feather);

    // Body: radial shading gives the torso a rounded, 3D volume.
    final bodyRect = Rect.fromLTWH(-5.5, -8.5, 11, 17);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [wingHighlight, bodyBase, bodyShadow],
          stops: const [0.0, .55, 1.0],
        ).createShader(bodyRect),
    );
    // Head with a small specular catch.
    canvas.drawCircle(const Offset(0, -7), 4.4, Paint()..color = bodyBase);
    canvas.drawCircle(const Offset(-1.2, -8.2), 1.3,
        Paint()..color = wingHighlight.withOpacity(.8));

    // Tail feather.
    final tail = Path()..moveTo(-2, 4)..lineTo(-7, 9)..lineTo(2, 7)..close();
    canvas.drawPath(tail, Paint()..color = bodyShadow);

    // Beak: gradient with a darkening tip.
    final beak = Path()..moveTo(-2, -9)..lineTo(0, -14)..lineTo(2, -9)..close();
    canvas.drawPath(
      beak,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB300), Color(0xFF6D4C00)],
        ).createShader(const Rect.fromLTWH(-2, -14, 4, 5)),
    );

    // Eye.
    canvas.drawCircle(const Offset(1.4, -7.6), 1.1,
        Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(const Offset(1.7, -8.0), .4,
        Paint()..color = Colors.white);

    if (isGolden) {
      final spark = Paint()..color = Colors.white.withOpacity(0.85);
      canvas.drawCircle(const Offset(-6, -2), 1.2, spark);
      canvas.drawCircle(const Offset(6, -2), 1.2, spark);
    }

    canvas.restore();
  }
}

