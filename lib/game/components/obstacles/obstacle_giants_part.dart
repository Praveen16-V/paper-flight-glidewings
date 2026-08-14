// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 18. FlockMigrationObstacle — Large V Formation Crossing the Sky
// ─────────────────────────────────────────────────────────────────────────────

class FlockMigrationObstacle extends ObstacleComponent {
  FlockMigrationObstacle() : super(type: ObstacleType.flockMigration);

  final List<_FlockBird> _birds = [];
  final List<CircleHitbox> _hitboxes = [];
  double _leaderX = 0;
  double _direction = 1;

  @override
  Color get telegraphColor => const Color(0xFFFFF9C4);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 190);
    position.x = GameConfig.designWidth * .5;
    _direction = rngBool() ? 1.0 : -1.0;
    _leaderX = _direction > 0 ? -42.0 : GameConfig.designWidth + 42.0;
    _birds.clear();
    _hitboxes.clear();
    removeAll(children.whereType<ShapeHitbox>().toList());

    final count = rngInt(10, 20);
    for (var i = 0; i < count; i++) {
      final rank = (i + 1) ~/ 2;
      final side = i.isEven ? -1.0 : 1.0;
      final bird = _FlockBird(
        behind: rank * 20.0,
        side: side,
        rise: rank * 11.0 + rngRange(-3, 3),
        size: rngRange(5.5, 8.5),
        phase: rngRange(0, math.pi * 2),
      );
      _birds.add(bird);
      final hitbox = CircleHitbox(radius: bird.size * .72);
      _hitboxes.add(hitbox);
      add(hitbox);
    }
    _syncBirdHitboxes();
  }

  @override
  void updateObstacle(double dt) {
    _leaderX += _direction * (130 + game.scrollSpeed * .22) * dt;
    _syncBirdHitboxes();
    if ((_direction > 0 && _leaderX > GameConfig.designWidth + 180) ||
        (_direction < 0 && _leaderX < -180)) {
      _active = false;
      onRecycle?.call(this);
    }
  }

  void _syncBirdHitboxes() {
    for (var i = 0; i < _birds.length; i++) {
      final bird = _birds[i];
      final pos = _birdPosition(bird);
      final hitbox = _hitboxes[i];
      hitbox.position = pos - Vector2.all(bird.size * .72);
    }
  }

  Vector2 _birdPosition(_FlockBird bird) {
    // The V opens behind the leader, opposite the direction of travel.
    final x = _leaderX - _direction * bird.behind + bird.side * bird.behind * .35;
    final y = 58 + bird.rise;
    return Vector2(x, y);
  }

  @override
  void render(Canvas canvas) {
    for (final bird in _birds) {
      final pos = _birdPosition(bird);
      final flap = math.sin(animTime * 12 + bird.phase) * bird.size * .55;
      final shape = Path()
        ..moveTo(pos.x, pos.y)
        ..quadraticBezierTo(pos.x - bird.size, pos.y - flap, pos.x - bird.size * 1.8, pos.y)
        ..quadraticBezierTo(pos.x - bird.size, pos.y + flap * .4, pos.x, pos.y)
        ..quadraticBezierTo(pos.x + bird.size, pos.y - flap, pos.x + bird.size * 1.8, pos.y)
        ..quadraticBezierTo(pos.x + bird.size, pos.y + flap * .4, pos.x, pos.y)
        ..close();
      // Gradient body: darker wingtip sinking toward the body center.
      final shapeRect = shape.getBounds();
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF0F1417)],
            stops: const [0.0, .55, 1.0],
          ).createShader(shapeRect),
      );
      // Specular ridge across the back.
      canvas.drawPath(shape, Paint()..color = const Color(0x22FFFFFF)..style = PaintingStyle.stroke..strokeWidth = .8);
    }
    renderTelegraph(canvas);
  }
}

class _FlockBird {
  const _FlockBird({
    required this.behind,
    required this.side,
    required this.rise,
    required this.size,
    required this.phase,
  });

  final double behind;
  final double side;
  final double rise;
  final double size;
  final double phase;
}

// ─────────────────────────────────────────────────────────────────────────────
// 19. WhaleBreachObstacle — Massive Slow Ocean Breach with Splash
// ─────────────────────────────────────────────────────────────────────────────

class WhaleBreachObstacle extends ObstacleComponent {
  WhaleBreachObstacle() : super(type: ObstacleType.whaleBreach);

  @override
  Color get telegraphColor => const Color(0xFF80D8FF);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(270, 190);
    // Slight horizontal variance keeps the breach from becoming a memorised
    // dead-centre lane while staying fully readable by its area telegraph.
    position.x =
        GameConfig.designWidth * .5 + rngRange(-38.0, 38.0);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(206, 88), position: Vector2(30, 54)));
    add(CircleHitbox(radius: 36, position: Vector2(194, 38)));
  }

  @override
  void updateObstacle(double dt) {
    // Base update scrolls with the world. Subtracting here gives the enormous
    // animal a slower, dramatic breach across the player row.
    position.y -= game.scrollSpeed * dt * .55;
  }

  @override
  void render(Canvas canvas) {
    final body = Path()
      ..moveTo(20, 120)
      ..quadraticBezierTo(72, 42, 194, 60)
      ..quadraticBezierTo(246, 70, 250, 106)
      ..quadraticBezierTo(222, 150, 120, 150)
      ..quadraticBezierTo(48, 150, 20, 120)
      ..close();
    final belly = Path()
      ..moveTo(54, 124)
      ..quadraticBezierTo(130, 112, 230, 108)
      ..quadraticBezierTo(208, 142, 118, 144)
      ..quadraticBezierTo(72, 141, 54, 124)
      ..close();
    // Body with a radial sheen: wet, sky-lit top blending into deep ocean blue.
    final bodyRect = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.45),
          radius: 1.05,
          colors: const [Color(0xFF64B5F6), Color(0xFF1565C0), Color(0xFF0D47A1)],
          stops: const [0.0, .55, 1.0],
        ).createShader(bodyRect),
    );
    // Glossy highlight sweeping along the back.
    final gloss = Path()
      ..moveTo(56, 88)
      ..quadraticBezierTo(120, 56, 210, 72)
      ..quadraticBezierTo(150, 90, 90, 96)
      ..quadraticBezierTo(70, 96, 56, 88)
      ..close();
    canvas.drawPath(gloss, Paint()..color = const Color(0x2EFFFFFF));
    canvas.drawPath(
      belly,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE1F5FE), Color(0xFFB3E5FC), Color(0xFF81D4FA)],
        ).createShader(belly.getBounds()),
    );

    // Dorsal fin and tail read clearly as a giant living silhouette.
    final fin = Path()
      ..moveTo(104, 72)
      ..lineTo(124, 24)
      ..lineTo(144, 78)
      ..close();
    canvas.drawPath(
      fin,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
        ).createShader(fin.getBounds()),
    );
    final tail = Path()
      ..moveTo(28, 112)
      ..quadraticBezierTo(2, 85, 0, 112)
      ..quadraticBezierTo(10, 137, 30, 122)
      ..quadraticBezierTo(6, 151, 2, 170)
      ..quadraticBezierTo(34, 154, 42, 125)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
        ).createShader(tail.getBounds()),
    );

    canvas.drawCircle(const Offset(220, 78), 3.2, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(221, 78), 1.3, Paint()..color = const Color(0xFF102027));
    // Eye specular catch.
    canvas.drawCircle(const Offset(218.8, 77), 1.0, Paint()..color = const Color(0x55FFFFFF));

    final spray = Paint()..color = const Color(0x99E1F5FE);
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi / 13 + animTime * .8;
      final radius = 50 + (i % 4) * 10 + math.sin(animTime * 4 + i) * 5;
      final x = 92 + math.cos(a) * radius;
      final y = 142 + math.sin(a) * radius * .55;
      canvas.drawCircle(Offset(x, y), 1.5 + (i % 3) * .45, spray);
    }
    renderTelegraph(canvas);
  }
}

