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

  @override
  Color get telegraphColor => const Color(0xFFFFB74D);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 48);
    _gapWidth = rngRange(100, 130);
    _gapX = rngRange(50, GameConfig.designWidth - _gapWidth - 50);

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(_gapX, 36), position: Vector2(0, 6)));
    final rStart = _gapX + _gapWidth;
    add(RectangleHitbox(size: Vector2(GameConfig.designWidth - rStart, 36), position: Vector2(rStart, 6)));
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
    final pinPaint = Paint()..color = const Color(0xFF4E342E)..style = PaintingStyle.fill;

    for (double x = startX + 15; x < endX - 15; x += 28) {
      // Wooden clothespin.
      canvas.drawRect(Rect.fromLTWH(x - 2, 8, 4, 4), pinPaint);
      // Doll with a soft gradient (lit top, shadowed base) + drop shadow.
      final dollRect = Rect.fromLTWH(x - 8, 12, 16, 22);
      final doll = Path()..moveTo(x, 12)..lineTo(x + 8, 22)..lineTo(x + 5, 34)..lineTo(x - 5, 34)..lineTo(x - 8, 22)..close();
      canvas.drawPath(
        doll,
        Paint()
          ..color = const Color(0x22000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        doll,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFECB3), Color(0xFFFFC107), Color(0xFFB8860B)],
            stops: const [0.0, .55, 1.0],
          ).createShader(dollRect),
      );
      canvas.drawPath(
        doll,
        Paint()
          ..color = const Color(0x66855C00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 14. WindSockObstacle (NEW) — Dynamic Wind-Direction Aviation Windsock
// ─────────────────────────────────────────────────────────────────────────────

class WindSockObstacle extends ObstacleComponent {
  WindSockObstacle() : super(type: ObstacleType.windsock);

  bool _kiteLinked = false;

  @override
  Color get telegraphColor => const Color(0xFFFF6D00);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(48, 54);
    _kiteLinked = false;
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(36, 40), position: Vector2(6, 6)));
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _kiteLinked = synergy == ObstacleSynergy.windTether;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    // Steel mast with a specular edge.
    canvas.drawRect(Rect.fromLTWH(cx - 1.2, 0, 2.4, 54),
        Paint()..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFB0BEC5), Color(0xFF607D8B), Color(0xFF37474F)],
        ).createShader(Rect.fromLTWH(cx - 1.2, 0, 2.4, 54)));
    canvas.drawRect(Rect.fromLTWH(cx - 1, 0, 1, 54),
        Paint()..color = const Color(0x55FFFFFF));

    // Striped windsock cone with a lit upper surface and shaded underside.
    final sock = Path()
      ..moveTo(cx, 8)
      ..lineTo(cx + 24, 14)
      ..lineTo(cx + 22, 28)
      ..lineTo(cx, 24)
      ..close();
    canvas.drawPath(
      sock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFF8A65), Color(0xFFD84315), Color(0xFF6D1200)],
          stops: const [0.0, .55, 1.0],
        ).createShader(sock.getBounds()),
    );

    // White stripes clipped to the cone (darker at the shaded base).
    final whiteStripes = Paint()..color = const Color(0xFFFBE9E7);
    canvas.drawRect(Rect.fromLTWH(cx + 6, 9.5, 6, 15), whiteStripes);
    canvas.drawRect(Rect.fromLTWH(cx + 15, 12, 5, 13), whiteStripes);
    canvas.drawRect(Rect.fromLTWH(cx + 3, 10, 3, 13),
        Paint()..color = const Color(0xFFFFCCBC));
    // Top highlight along the cone.
    canvas.drawPath(
      Path()..moveTo(cx, 8)..lineTo(cx + 24, 14)..lineTo(cx + 22, 15)..lineTo(cx, 10)..close(),
      Paint()..color = const Color(0x33FFFFFF),
    );
    if (_kiteLinked) {
      final windPaint = Paint()
        ..color = ObstacleSynergy.windTether.color.withOpacity(.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25;
      for (var i = 0; i < 3; i++) {
        final y = 12.0 + i * 8.0;
        canvas.drawLine(Offset(cx + 24, y), Offset(cx + 38, y - 2), windPaint);
      }
    }

    renderTelegraph(canvas);
  }
}

