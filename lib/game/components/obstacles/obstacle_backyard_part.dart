// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 13. ClotheslineObstacle (NEW) — Backyard Clothesline with Paper Cutout Dolls
// ─────────────────────────────────────────────────────────────────────────────

class ClotheslineObstacle extends ObstacleComponent {
  ClotheslineObstacle() : super(type: ObstacleType.clothesline);

  double _gapX = 120;
  double _gapWidth = 105;
  double _flutterPhase = 0;

  @override
  Color get telegraphColor => const Color(0xFFFFB74D);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 48);
    _gapWidth = script?.gapWidth ?? rngRange(106, 132);
    _flutterPhase = rngRange(0, math.pi * 2);
    final minGapX = GameConfig.horizontalEdgeMargin + 28;
    final maxGapX =
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - _gapWidth - 28;
    final scriptedCenter = script?.gapCenterX;
    _gapX = scriptedCenter != null
        ? (scriptedCenter - _gapWidth * .5)
            .clamp(minGapX, maxGapX)
            .toDouble()
        : safeCorridorX != null
            ? (safeCorridorX! - _gapWidth * .5)
                .clamp(minGapX, maxGapX)
                .toDouble()
            : rngRange(minGapX, maxGapX);

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(_gapX, 36), position: Vector2(0, 6)));
    final rStart = _gapX + _gapWidth;
    add(RectangleHitbox(size: Vector2(GameConfig.designWidth - rStart, 36), position: Vector2(rStart, 6)));
  }

  @override
  void updateObstacle(double dt) {
    _flutterPhase += dt * 4.2;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final rStart = _gapX + _gapWidth;

    // Rounded, sunlit rope.
    canvas.drawLine(Offset(0, 11), Offset(_gapX, 13),
        Paint()..color = const Color(0xFF4E342E)..strokeWidth = 2.4..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(rStart, 13), Offset(w, 11),
        Paint()..color = const Color(0xFF4E342E)..strokeWidth = 2.4..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(0, 10), Offset(_gapX, 12),
        Paint()..color = const Color(0xFFA1887F)..strokeWidth = 1.0);
    canvas.drawLine(Offset(rStart, 12), Offset(w, 10),
        Paint()..color = const Color(0xFFA1887F)..strokeWidth = 1.0);

    // Wooden support poles.
    final pole = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFA1887F), Color(0xFF5D4037)],
      ).createShader(const Rect.fromLTWH(0, 0, 5, 40));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 5, 40), pole);
    canvas.drawRect(Rect.fromLTWH(w - 5, 0, 5, 40), pole);

    // Paper dolls hanging with clothespins
    _drawPaperDolls(canvas, 0, _gapX);
    _drawPaperDolls(canvas, rStart, w);

    renderTelegraph(canvas);
  }

  @override
  void renderThreatPreview(
    Canvas canvas,
    double x,
    double y,
    double progress,
    double pulse,
  ) {
    renderSafeCorridorPreview(
      canvas,
      localY: y + GameConfig.telegraphProjectionStartOffset + 22,
      gapLeft: _gapX,
      gapWidth: _gapWidth,
      progress: progress,
      pulse: pulse,
    );
  }

  void _drawPaperDolls(Canvas canvas, double startX, double endX) {
    final pinPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.fill;
    const palettes = [
      [Color(0xFFFFECB3), Color(0xFFFFC107), Color(0xFFB8860B)],
      [Color(0xFFE1F5FE), Color(0xFF4FC3F7), Color(0xFF0277BD)],
      [Color(0xFFFCE4EC), Color(0xFFF48FB1), Color(0xFFC2185B)],
    ];

    var index = 0;
    for (double x = startX + 15; x < endX - 15; x += 28) {
      // Wooden clothespin remains fixed while the paper below it catches the
      // same breeze that drives the world wind.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2.2, 8, 4.4, 5),
          const Radius.circular(.8),
        ),
        pinPaint,
      );

      final flutter = math.sin(_flutterPhase + x * .085) * .11;
      final lift = math.cos(_flutterPhase * 1.3 + x * .04) * 1.4;
      canvas.save();
      canvas.translate(x, 12 + lift);
      canvas.rotate(flutter);

      final dollRect = const Rect.fromLTWH(-8, 0, 16, 22);
      final doll = Path()
        ..moveTo(0, 0)
        ..lineTo(8, 10)
        ..lineTo(5, 22)
        ..lineTo(-5, 22)
        ..lineTo(-8, 10)
        ..close();
      canvas.save();
      canvas.translate(1.2, 1.8);
      canvas.drawPath(
        doll,
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.restore();

      final palette = palettes[index % palettes.length];
      canvas.drawPath(
        doll,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette,
            stops: const [0.0, .55, 1.0],
          ).createShader(dollRect),
      );
      canvas.drawLine(
        const Offset(-5.5, 10),
        const Offset(5.5, 10),
        Paint()
          ..color = Colors.white.withOpacity(.34)
          ..strokeWidth = .8,
      );
      canvas.drawPath(
        doll,
        Paint()
          ..color = palette.last.withOpacity(.68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      canvas.restore();
      index++;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 14. WindSockObstacle (NEW) — Dynamic Wind-Direction Aviation Windsock
// ─────────────────────────────────────────────────────────────────────────────

class WindSockObstacle extends ObstacleComponent {
  WindSockObstacle() : super(type: ObstacleType.windsock);

  bool _kiteLinked = false;
  double _flutterPhase = 0;
  double _windDirection = 1;

  @override
  Color get telegraphColor => const Color(0xFFFF6D00);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(48, 54);
    _kiteLinked = false;
    _flutterPhase = rngRange(0, math.pi * 2);
    _windDirection = rngBool() ? 1 : -1;
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(36, 40), position: Vector2(6, 6)));
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _kiteLinked = synergy == ObstacleSynergy.windTether;
  }

  @override
  void updateObstacle(double dt) {
    _flutterPhase += dt * (_kiteLinked ? 7.4 : 5.2);
    final force = game.windSystem.currentForceAt(position.x);
    if (force.abs() > 4) _windDirection = force.sign;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    // Steel mast with a specular edge and a grounded foot, so the obstacle
    // remains readable against both pale morning skies and dark storm biomes.
    final mastRect = Rect.fromLTWH(cx - 1.4, 0, 2.8, 54);
    canvas.drawRect(
      mastRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFCFD8DC), Color(0xFF607D8B), Color(0xFF263238)],
        ).createShader(mastRect),
    );
    canvas.drawRect(Rect.fromLTWH(cx - 1, 0, .8, 54),
        Paint()..color = const Color(0x66FFFFFF));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 51), width: 14, height: 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF37474F),
    );

    // Mirror around the mast when the real local wind changes direction. The
    // tip also ripples vertically, making this a live wind instrument rather
    // than a static cone pasted over the playfield.
    canvas.save();
    canvas.translate(cx, 0);
    canvas.scale(_windDirection, 1);
    canvas.translate(-cx, 0);
    final tipWave = math.sin(_flutterPhase) * 3.1;
    final midWave = math.sin(_flutterPhase * .78 + 1.2) * 1.8;
    final sock = Path()
      ..moveTo(cx, 8)
      ..quadraticBezierTo(cx + 12, 10 + midWave, cx + 24, 14 + tipWave)
      ..lineTo(cx + 22, 27 + tipWave)
      ..quadraticBezierTo(cx + 11, 24 - midWave, cx, 24)
      ..close();
    final bounds = sock.getBounds();

    canvas.save();
    canvas.clipPath(sock);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFAB91), Color(0xFFD84315), Color(0xFF6D1200)],
          stops: [0.0, .56, 1.0],
        ).createShader(bounds),
    );
    final whiteStripe = Paint()..color = const Color(0xFFFBE9E7);
    canvas.drawRect(Rect.fromLTWH(cx + 6, 7, 5.5, 24), whiteStripe);
    canvas.drawRect(Rect.fromLTWH(cx + 15, 8, 4.8, 24), whiteStripe);
    canvas.drawRect(
      Rect.fromLTWH(cx, 8, 24, 4.2),
      Paint()..color = const Color(0x38FFFFFF),
    );
    canvas.restore();
    canvas.drawPath(
      sock,
      Paint()
        ..color = const Color(0xFF7F230C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    if (_kiteLinked) {
      final windPaint = Paint()
        ..color = ObstacleSynergy.windTether.color.withOpacity(.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final y = 11.0 + i * 8.0 + math.sin(_flutterPhase + i) * 1.5;
        canvas.drawLine(
          Offset(cx + 26, y),
          Offset(cx + 38, y - 2),
          windPaint,
        );
      }
    }
    canvas.restore();

    renderTelegraph(canvas);
  }
}

