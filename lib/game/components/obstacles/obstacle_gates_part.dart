// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. PowerLineObstacle — Sagging Catenary Cables, Magnet Chaining Sparks
// ─────────────────────────────────────────────────────────────────────────────

class PowerLineObstacle extends ObstacleComponent {
  PowerLineObstacle() : super(type: ObstacleType.powerLine);

  double _gapX = 0;
  double _gapWidth = 95;
  double _sparkTimer = 0;
  double _sparkX = 0;
  double _sparkAlpha = 0;
  bool _sparkOnLeft = true;

  /// Cached once per simulation tick (never inside render) so the spark-chain
  /// visual costs a boolean instead of a provider read per frame.
  bool _magnetChaining = false;

  @override
  Color get telegraphColor => const Color(0xFFFFD54F);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 40);
    final scriptedGapWidth = script?.gapWidth;
    _gapWidth = scriptedGapWidth ?? rngRange(92, 125);
    final minGapX = GameConfig.horizontalEdgeMargin + 35;
    final maxGapX =
        GameConfig.designWidth - GameConfig.horizontalEdgeMargin - _gapWidth - 35;
    final scriptedCenter = script?.gapCenterX;
    _gapX = scriptedCenter != null
        ? (scriptedCenter - _gapWidth / 2).clamp(minGapX, maxGapX).toDouble()
        : safeCorridorX == null
            ? rngRange(minGapX, maxGapX)
            : (safeCorridorX! - _gapWidth / 2)
                .clamp(minGapX, maxGapX)
                .toDouble();
    _sparkTimer = rngRange(0.5, 2.0);
    _sparkAlpha = 0;
    _magnetChaining = false;
    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(_gapX, 22), position: Vector2(0, 8)));
    final rightStart = _gapX + _gapWidth;
    add(RectangleHitbox(
      size: Vector2(GameConfig.designWidth - rightStart, 22),
      position: Vector2(rightStart, 8),
    ));
    add(RectangleHitbox(size: Vector2(18, 40), position: Vector2(0, 0)));
    add(RectangleHitbox(
      size: Vector2(18, 40),
      position: Vector2(GameConfig.designWidth - 18, 0),
    ));
  }

  @override
  void updateObstacle(double dt) {
    _magnetChaining = game.powerUpState.magnetActive;
    _sparkTimer -= dt;
    if (_sparkTimer <= 0) {
      _sparkTimer = rngRange(1.8, 3.5);
      _sparkAlpha = 1.0;
      _sparkOnLeft = rngBool();
      if (_sparkOnLeft) {
        _sparkX = rngRange(25, math.max(30, _gapX - 15));
      } else {
        final rightStart = _gapX + _gapWidth;
        _sparkX = rngRange(rightStart + 15, GameConfig.designWidth - 25);
      }
    }
    if (_sparkAlpha > 0) {
      _sparkAlpha = (_sparkAlpha - dt * 3.5).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rightStart = _gapX + _gapWidth;

    // Sparks chain continuously while the Magnet power-up is active — the
    // flag is cached by updateObstacle so render stays allocation-free.
    final magnetChaining = _magnetChaining;

    _drawPylonTower(canvas, 0, h);
    _drawPylonTower(canvas, w - 16, h);

    // Dark recessed core of each cable.
    final wirePaint = Paint()
      ..color = const Color(0xFF1C2529)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Lit cable body (drawn slightly higher to read as a rounded 3D cylinder).
    final wireBody = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Thin specular highlight along the top of the cable.
    final wireHighlight = Paint()
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sagOffsets = [8.0, 16.0, 24.0];
    for (int i = 0; i < sagOffsets.length; i++) {
      final yOff = sagOffsets[i];
      final sagAmount = 5.0 + i * 1.5;

      final leftPath = Path()
        ..moveTo(14, yOff)
        ..quadraticBezierTo(
            _gapX * 0.5, yOff + sagAmount, _gapX, yOff + sagAmount * 0.5);
      final rightSpan = w - 14 - rightStart;
      final rightPath = Path()
        ..moveTo(rightStart, yOff + sagAmount * 0.5)
        ..quadraticBezierTo(
            rightStart + rightSpan * 0.5, yOff + sagAmount, w - 14, yOff);

      for (final path in [leftPath, rightPath]) {
        canvas.drawPath(path, wirePaint);
        canvas.drawPath(path, wireBody);
        // Offset the highlight ~1px up to fake the cable's rounded surface.
        canvas.save();
        canvas.translate(0, -1.0);
        canvas.drawPath(path, wireHighlight);
        canvas.restore();
      }

      // Magnet spark chain interaction
      if (magnetChaining) {
        final chainPaint = Paint()
          ..color = (i % 2 == 0)
              ? const Color(0xFFAB47BC).withOpacity(0.7)
              : const Color(0xFF00E5FF).withOpacity(0.7)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke;
        canvas.drawPath(leftPath, chainPaint);
        canvas.drawPath(rightPath, chainPaint);
      }
    }

    _drawMarkerFlags(canvas, 0, _gapX, 16);
    _drawMarkerFlags(canvas, rightStart, w, 16);
    _drawGapMarkers(canvas, _gapX, rightStart, 16);

    if (_sparkAlpha > 0 || magnetChaining) {
      _drawElectricSpark(
          canvas, _sparkX, 16, magnetChaining ? 0.9 : _sparkAlpha);
    }

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

  void _drawPylonTower(Canvas canvas, double x, double h) {
    // Tapered lattice tower: the legs converge toward the top, with a
    // two-tone gradient giving the steel structure a lit/shaded 3D face.
    final topW = 11.0;
    final baseW = 17.0;
    final centerX = x + baseW * 0.5;
    const topY = 2.0;
    final span = h - topY;

    double halfWAt(double t) => topW * 0.5 + (baseW - topW) * 0.5 * t;

    final towerPath = Path()
      ..moveTo(centerX - halfWAt(0), topY)
      ..lineTo(centerX + halfWAt(0), topY)
      ..lineTo(centerX + halfWAt(1), h)
      ..lineTo(centerX - halfWAt(1), h)
      ..close();
    canvas.drawPath(
      towerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Color(0xFF90A4AE), Color(0xFF455A64), Color(0xFF263238)],
          stops: const [0.0, .55, 1.0],
        ).createShader(Rect.fromLTWH(x, topY, baseW, span)),
    );

    // Horizontal cross-arms + X-lattice braces.
    final truss = Paint()
      ..color = const Color(0xFF1C2529)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final brace = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const steps = 4;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final y = topY + span * t;
      final hw = halfWAt(t);
      canvas.drawLine(Offset(centerX - hw, y), Offset(centerX + hw, y), truss);
    }
    for (var i = 0; i < steps; i++) {
      final t0 = i / steps;
      final t1 = (i + 1) / steps;
      final y0 = topY + span * t0;
      final y1 = topY + span * t1;
      final hw0 = halfWAt(t0);
      final hw1 = halfWAt(t1);
      canvas.drawLine(
          Offset(centerX - hw0, y0), Offset(centerX + hw1, y1), brace);
      canvas.drawLine(
          Offset(centerX + hw0, y0), Offset(centerX - hw1, y1), brace);
    }

    // Specular edge on the sunlit side.
    canvas.drawLine(Offset(centerX - halfWAt(.4), topY + span * .4),
        Offset(centerX - halfWAt(1), h),
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..strokeWidth = 1.4);

    // Porcelain insulators where the cables attach.
    final insulator = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFB0BEC5)],
      ).createShader(Rect.fromLTWH(x + 12, 5, 3, 14));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 12, 5, 3, 14),
          const Radius.circular(1)),
      insulator,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 14, 3, 14),
          const Radius.circular(1)),
      insulator,
    );
  }

  void _drawMarkerFlags(
      Canvas canvas, double startX, double endX, double baseH) {
    final flagPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final span = endX - startX;
    if (span < 45) return;

    final flagCount = (span / 40).floor();
    for (int i = 1; i <= flagCount; i++) {
      final fx = startX + (span / (flagCount + 1)) * i;
      final wave = math.sin(animTime * 8.0 + fx * 0.1) * 3.5;

      canvas.drawCircle(Offset(fx, baseH), 3.5, flagPaint);
      canvas.drawCircle(Offset(fx, baseH), 1.8, whitePaint);

      final pennant = Path()
        ..moveTo(fx, baseH + 3)
        ..lineTo(fx + 5 + wave, baseH + 11)
        ..lineTo(fx, baseH + 9)
        ..close();
      canvas.drawPath(pennant, flagPaint);
    }
  }

  void _drawGapMarkers(
      Canvas canvas, double leftGapX, double rightGapX, double cy) {
    final glow = (math.sin(animTime * 6.0) * 0.35 + 0.65);
    final guidePaint = Paint()
      ..color = const Color(0xFF4FC3F7).withOpacity(glow * 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(leftGapX, cy), 4.5, guidePaint);
    canvas.drawCircle(Offset(rightGapX, cy), 4.5, guidePaint);
  }

  void _drawElectricSpark(Canvas canvas, double x, double y, double alpha) {
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(alpha * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final corePaint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(x, y), 10, glowPaint);

    final lightning = Path()..moveTo(x - 8, y + math.sin(animTime * 30) * 4);
    lightning.lineTo(x - 3, y - 5);
    lightning.lineTo(x + 2, y + 4);
    lightning.lineTo(x + 7, y - 3);
    lightning.lineTo(x + 10, y + 2);
    canvas.drawPath(lightning, corePaint);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. BuildingObstacle — Skyscrapers, Batch Windows, Rooftop Billboards
// ─────────────────────────────────────────────────────────────────────────────

class BuildingObstacle extends ObstacleComponent {
  BuildingObstacle() : super(type: ObstacleType.building);

  double _leftWidth = 0;
  double _gapWidth = 115;
  int _style = 0;
  int _billboardIndex = 0;

  static const List<String> _billboardLabels = [
    'GLIDE',
    'FLY',
    'PAPER CO',
    'CATCH WIND',
  ];

  /// Billboard glyphs are laid out once per label and shared by every pooled
  /// building — render never pays a TextPainter build again.
  static final List<TextPainter> _billboardPainters = _billboardLabels
      .map(
        (label) => TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 6.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFE082),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      )
      .toList(growable: false);

  double get gapLeft => _leftWidth;
  double get gapRight => _leftWidth + _gapWidth;
  double get gapWidth => _gapWidth;

  @override
  Color get telegraphColor => const Color(0xFFE53935);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 230);
    final scriptedGapWidth = script?.gapWidth;
    _gapWidth = scriptedGapWidth ?? rngRange(100, 135);
    const minGapX = 50.0;
    final maxGapX = GameConfig.designWidth - _gapWidth - 50;
    final scriptedCenter = script?.gapCenterX;
    _leftWidth = scriptedCenter != null
        ? (scriptedCenter - _gapWidth / 2).clamp(minGapX, maxGapX).toDouble()
        : safeCorridorX == null
            ? rngRange(minGapX, maxGapX)
            : (safeCorridorX! - _gapWidth / 2)
                .clamp(minGapX, maxGapX)
                .toDouble();
    _style = rngInt(0, 2);
    _billboardIndex = rngInt(0, 3);
    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(
      size: Vector2(_leftWidth, size.y),
      position: Vector2.zero(),
    ));
    final rightStart = _leftWidth + _gapWidth;
    add(RectangleHitbox(
      size: Vector2(GameConfig.designWidth - rightStart, size.y),
      position: Vector2(rightStart, 0),
    ));
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rightStart = _leftWidth + _gapWidth;
    final rightWidth = w - rightStart;

    _drawBuildingTower(canvas, 0, _leftWidth, h, isLeft: true);
    _drawBuildingTower(canvas, rightStart, rightWidth, h, isLeft: false);

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
      gapLeft: _leftWidth,
      gapWidth: _gapWidth,
      progress: progress,
      pulse: pulse,
    );
  }

  void _drawBuildingTower(
      Canvas canvas, double startX, double bw, double bh,
      {required bool isLeft}) {
    if (bw <= 0) return;

    // Biome-specific facade tinting
    final Biome currentBiome = gameRef.biomeManager.currentBiome;
    final Color base = switch (currentBiome) {
      Biome.city => const Color(0xFF90A4AE),       // cool blue-grey skyscraper
      Biome.storm => const Color(0xFF455A64),      // dark storm-worn slate
      Biome.night => const Color(0xFF3949AB),      // midnight navy noir
      Biome.atmosphere => const Color(0xFF37474F), // high-altitude carbon
      _ => const Color(0xFFD7B98C),                // warm kraft tan
    };
    final Color baseLight = Color.lerp(base, Colors.white, .18)!;
    final Color baseDark = Color.lerp(base, Colors.black, .32)!;
    final Color deepShadow = Color.lerp(base, Colors.black, .55)!;

    final towerRect =
        RRect.fromRectAndRadius(Rect.fromLTWH(startX, 0, bw, bh),
            const Radius.circular(2));

    // Atmospheric vertical gradient: sky-lit top sinking into a dark base.
    final facade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [baseLight, base, baseDark],
        stops: const [0.0, .55, 1.0],
      ).createShader(towerRect.outerRect);
    // Soft horizontal vignette so the slab reads as a solid 3D mass.
    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x30FFFFFF),
          Color(0x00FFFFFF),
          Color(0x33000000),
          Color(0x00FFFFFF),
          Color(0x30FFFFFF),
        ],
        stops: const [0.0, .25, .5, .75, 1.0],
      ).createShader(towerRect.outerRect);

    canvas.drawRRect(towerRect, facade);
    canvas.drawRRect(towerRect, vignette);

    // 3D side wall: the edge facing the flight corridor recedes and catches
    // shadow, making both towers read as solid masses on either side of the gap.
    final sideW = math.min(12.0, bw * .22);
    final sideRect = Rect.fromLTWH(
        isLeft ? startX + bw - sideW : startX, 0, sideW, bh);
    final side = Paint()
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        colors: [baseDark, deepShadow],
      ).createShader(sideRect);
    canvas.drawRect(sideRect, side);

    // Bright corner catch-light along the outer edge.
    final edgeW = math.min(2.5, bw * .05);
    final edgeX = isLeft ? startX : startX + bw - edgeW;
    canvas.drawRect(
      Rect.fromLTWH(edgeX, 0, edgeW, bh),
      Paint()..color = Color.lerp(baseLight, Colors.white, .35)!.withOpacity(.8),
    );

    // Mid-height setback band + ambient occlusion at the base.
    canvas.drawRect(
      Rect.fromLTWH(startX, bh * .5, bw, 4),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [baseDark, deepShadow],
        ).createShader(Rect.fromLTWH(startX, bh * .5, bw, 4)),
    );
    canvas.drawRect(Rect.fromLTWH(startX, bh - 8, bw, 8),
        Paint()..color = deepShadow.withOpacity(.55));

    _drawBatchedLitWindows(
        canvas, startX + (isLeft ? 6 : sideW + 5), bw - sideW - 11, bh);

    // 3D roof cap: bright sunlit top face over a dark recessed front lip.
    final capX = startX - 1.5;
    final capW = bw + 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(capX, -2, capW, 6), const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(baseLight, Colors.white, .5)!, baseLight],
        ).createShader(Rect.fromLTWH(capX, -2, capW, 6)),
    );
    canvas.drawRect(Rect.fromLTWH(capX, 4, capW, 3),
        Paint()..color = deepShadow.withOpacity(.78));

    // Rooftop Features & Environmental Storytelling Billboards
    if (bw > 45) {
      if (_style == 0) {
        _drawHvacFan(canvas, startX + bw * .4, 0);
        _drawRooftopBillboard(canvas, startX + bw * .5, 0, isLeft);
      } else if (_style == 1 && isLeft) {
        _drawWaterTower(canvas, startX + bw * .35, 0);
      } else {
        _drawAntennaSpire(canvas, startX + bw * .5, 0);
      }
    }
  }

  void _drawBatchedLitWindows(
      Canvas canvas, double startX, double usableW, double bh) {
    if (usableW < 12) return;

    const winW = 7.0;
    const winH = 9.0;
    const colGap = 15.0;
    const rowGap = 16.0;

    final framePath = Path();
    final warmPath = Path();
    final cyanPath = Path();
    final darkPath = Path();
    final highlightPath = Path();

    for (double x = startX; x < startX + usableW - winW; x += colGap) {
      for (double y = 18.0; y < bh - winH - 8; y += rowGap) {
        final hash = (x * 3.1 + y * 7.3).toInt();
        // Recessed frame slightly larger than the glass.
        framePath.addRect(Rect.fromLTWH(x - .7, y - .7, winW + 1.4, winH + 1.4));
        final glass = Rect.fromLTWH(x, y, winW, winH);
        if (hash % 4 == 0) {
          darkPath.addRect(glass);
        } else if (hash % 3 == 0) {
          cyanPath.addRect(glass);
        } else {
          warmPath.addRect(glass);
        }
        // A thin specular catch along the top of every pane.
        highlightPath.addRect(Rect.fromLTWH(x, y, winW, 1.8));
      }
    }

    final glassRect =
        Rect.fromLTWH(startX, 16, usableW, math.max(1.0, bh - 24));
    // Shared facade-wide gradients give every pane a consistent vertical light.
    canvas.drawPath(framePath, Paint()..color = const Color(0xFF111318));
    canvas.drawPath(
      warmPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
        ).createShader(glassRect),
    );
    canvas.drawPath(
      cyanPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB2EBF2), Color(0xFF1E88E5)],
        ).createShader(glassRect),
    );
    canvas.drawPath(
      darkPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16202B), Color(0xFF0D141C)],
        ).createShader(glassRect),
    );
    canvas.drawPath(highlightPath,
        Paint()..color = const Color(0x38FFFFFF));
  }

  void _drawRooftopBillboard(
      Canvas canvas, double cx, double cy, bool isLeft) {
    final tp = _billboardPainters[_billboardIndex % _billboardPainters.length];

    // Mounting post with a hint of thickness.
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + 1), width: 2.6, height: 12),
        Paint()..color = const Color(0xFF37474F));

    // Rear panel offset for 3D depth.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - 2, cy - 12), width: 34, height: 14),
          const Radius.circular(2)),
      Paint()..color = const Color(0xFF0C1113),
    );
    // Front face with a soft gradient + top highlight.
    final frontRect =
        Rect.fromCenter(center: Offset(cx, cy - 12), width: 34, height: 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frontRect, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF455A64), Color(0xFF102027)],
        ).createShader(frontRect),
    );
    canvas.drawRect(Rect.fromLTWH(cx - 16, cy - 19, 32, 1.4),
        Paint()..color = const Color(0x40FFFFFF));
    canvas.drawRRect(
      RRect.fromRectAndRadius(frontRect, const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    // Mini neon text painter with a subtle glow pass.
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - 12 - tp.height / 2));
  }

  void _drawHvacFan(Canvas canvas, double cx, double cy) {
    // Cylindrical unit body with a sky-lit top.
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + 4), width: 22, height: 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF90A4AE), const Color(0xFF37474F)],
        ).createShader(bodyRect),
    );
    canvas.drawRect(Rect.fromLTWH(cx - 11, cy - 2, 22, 1.6),
        Paint()..color = const Color(0x66FFFFFF));

    // Recessed dark fan opening.
    canvas.drawCircle(Offset(cx, cy + 4), 4.8,
        Paint()..color = const Color(0xFF0D1B1E));
    final angle = animTime * 16.0;
    canvas.save();
    canvas.translate(cx, cy + 4);
    canvas.rotate(angle);
    final bladePaint = Paint()..color = const Color(0xFFB0BEC5)..style = PaintingStyle.fill;
    final blade = Path()
      ..moveTo(-4.4, 0)
      ..quadraticBezierTo(0, -1.4, 4.4, 0)
      ..quadraticBezierTo(0, 1.4, -4.4, 0)
      ..close();
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      canvas.drawPath(blade, bladePaint);
      canvas.restore();
    }
    canvas.restore();

    canvas.drawCircle(Offset(cx, cy + 4), 1.3,
        Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(Offset(cx, cy + 4), 4.8,
        Paint()
          ..color = const Color(0xFF37474F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  void _drawWaterTower(Canvas canvas, double cx, double cy) {
    // Crossed tower legs.
    final legPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 8, cy + 12), Offset(cx - 6, cy + 3), legPaint);
    canvas.drawLine(Offset(cx + 8, cy + 12), Offset(cx + 6, cy + 3), legPaint);
    canvas.drawLine(Offset(cx - 3, cy + 12), Offset(cx - 2, cy + 3), legPaint);
    canvas.drawLine(Offset(cx + 3, cy + 12), Offset(cx + 2, cy + 3), legPaint);

    // Cylindrical tank with a lit left side and deep right shadow.
    final tankRect = Rect.fromCenter(center: Offset(cx, cy - 2), width: 18, height: 12);
    canvas.drawRect(
      tankRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF5D4037), Color(0xFF8D6E63), Color(0xFF3E2723)],
          stops: [0.0, .5, 1.0],
        ).createShader(tankRect),
    );
    // Lit elliptical top + conical roof.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 8), width: 18, height: 4.5),
      Paint()..color = const Color(0xFFA1887F),
    );
    final roofPath = Path()
      ..moveTo(cx - 10, cy - 8)
      ..lineTo(cx, cy - 17)
      ..lineTo(cx + 10, cy - 8)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = const Color(0xFF5D4037));
    // Surface highlight running down the tank.
    canvas.drawRect(Rect.fromLTWH(cx - 8, cy - 8, 4, 12),
        Paint()..color = const Color(0x33FFFFFF));
  }

  void _drawAntennaSpire(Canvas canvas, double cx, double cy) {
    // Steel mast with a thin specular edge.
    canvas.drawRect(Rect.fromLTWH(cx - .8, cy - 18, 1.6, 18),
        Paint()..color = const Color(0xFF90A4AE));
    canvas.drawRect(Rect.fromLTWH(cx - .4, cy - 18, .8, 18),
        Paint()..color = const Color(0x44FFFFFF));
    canvas.drawLine(Offset(cx - 5, cy - 8), Offset(cx + 5, cy - 8),
        Paint()..color = const Color(0xFF78909C)..strokeWidth = 1.2);

    // Pulsing aviation beacon with a soft halo.
    final pulse = (math.sin(animTime * 8.0) * .5 + .5);
    canvas.drawCircle(
      Offset(cx, cy - 18),
      3.6,
      Paint()
        ..color = Color.fromRGBO(255, 23, 68, .25 + pulse * .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(cx, cy - 18),
      1.7,
      Paint()..color = Color.fromRGBO(255, 23, 68, .55 + pulse * .45),
    );
  }
}

