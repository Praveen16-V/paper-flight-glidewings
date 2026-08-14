// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 7. HotAirBalloonObstacle — Buoyancy Rising Dynamics, Flame & Basket
// ─────────────────────────────────────────────────────────────────────────────

class HotAirBalloonObstacle extends ObstacleComponent {
  HotAirBalloonObstacle() : super(type: ObstacleType.hotAirBalloon);

  double _driftPhase = 0;
  double _driftAmp = 35;
  double _spawnX = 0;

  @override
  Color get telegraphColor => const Color(0xFFFF7043);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(72, 96);
    _spawnX = position.x;
    _driftAmp = script?.driftAmp ?? rngRange(25, 45);
    _driftPhase = rngRange(0, math.pi * 2);

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 32, position: Vector2(size.x * 0.5 - 32, 4)));
    add(RectangleHitbox(size: Vector2(22, 18), position: Vector2(size.x * 0.5 - 11, 74)));
  }

  @override
  void updateObstacle(double dt) {
    _driftPhase += dt * 1.2;
    // Buoyancy Dynamics: rises gently upward against world scroll speed
    position.y -= 16.0 * dt;
    position.x = (_spawnX + math.sin(_driftPhase) * _driftAmp * dynamicMovementFactor).clamp(
      GameConfig.horizontalEdgeMargin + 30,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 30,
    );
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = 34.0;

    final envelopeRect = Rect.fromLTWH(cx - 36, cy - 28, 72, 54);
    final envelopePath = Path()
      ..moveTo(cx - 14, cy + 24)
      ..cubicTo(cx - 36, cy + 10, cx - 36, cy - 26, cx, cy - 28)
      ..cubicTo(cx + 36, cy - 26, cx + 36, cy + 10, cx + 14, cy + 24)
      ..close();
    // Envelope base fill with a rich radial sheen (lit top-left).
    canvas.drawPath(
      envelopePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.05,
          colors: const [Color(0xFFFFAB91), Color(0xFFD32F2F), Color(0xFF7F0000)],
          stops: const [0.0, .6, 1.0],
        ).createShader(envelopeRect),
    );
    // Panel seams.
    final gore = Path()
      ..moveTo(cx - 7, cy + 24)
      ..cubicTo(cx - 16, cy + 8, cx - 16, cy - 25, cx, cy - 28)
      ..cubicTo(cx + 16, cy - 25, cx + 16, cy + 8, cx + 7, cy + 24)
      ..close();
    canvas.drawPath(
      gore,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE082), Color(0xFFF57F17), Color(0xFFFF8F00)],
          stops: const [0.0, .5, 1.0],
        ).createShader(envelopeRect),
    );
    // Sunlit specular arc across the crown.
    final specular = Path()
      ..moveTo(cx - 26, cy - 16)
      ..cubicTo(cx - 30, cy - 26, cx - 10, cy - 28, cx, cy - 27)
      ..cubicTo(cx + 12, cy - 26, cx + 30, cy - 24, cx + 26, cy - 14)
      ..close();
    canvas.drawPath(specular, Paint()..color = const Color(0x2EFFFFFF));

    // Burner + wicker basket with cylindrical shading.
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + 26), width: 4, height: 8),
        Paint()..color = const Color(0xFF37474F));
    final basketRect = Rect.fromCenter(center: Offset(cx, 82), width: 20, height: 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(basketRect, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFBCAAA4), Color(0xFF8D6E63), Color(0xFF4E342E)],
          stops: const [0.0, .5, 1.0],
        ).createShader(basketRect),
    );
    // Wicker weave + lit top rim.
    canvas.drawLine(Offset(cx - 9, 82), Offset(cx + 9, 82),
        Paint()..color = const Color(0xFF5D4037)..strokeWidth = 1.0);
    canvas.drawRect(Rect.fromLTWH(cx - 10, 75, 20, 1.5),
        Paint()..color = const Color(0x55FFFFFF));
    renderDestructibleIntegrity(canvas, centerX: cx, topY: 0);
    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. StormCloudObstacle — Electric Arcs & Rain
// ─────────────────────────────────────────────────────────────────────────────

class StormCloudObstacle extends ObstacleComponent {
  StormCloudObstacle() : super(type: ObstacleType.stormCloud);

  double _chargeTimer = 0;
  double _lightningAlpha = 0;
  bool _stormCharged = false;

  @override
  Color get telegraphColor => const Color(0xFF7C4DFF);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(100, 55);
    _chargeTimer = rngRange(1.2, 2.5);
    _lightningAlpha = 0;
    _stormCharged = false;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 24, position: Vector2(8, 4)));
    add(CircleHitbox(radius: 28, position: Vector2(size.x * 0.5 - 28, 0)));
    add(CircleHitbox(radius: 22, position: Vector2(size.x - 52, 6)));
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _stormCharged = synergy == ObstacleSynergy.stormCharge;
  }

  @override
  void updateObstacle(double dt) {
    _chargeTimer -= dt;
    if (_chargeTimer <= 0) {
      _chargeTimer = rngRange(2.0, 3.8);
      _lightningAlpha = 1.0;
    }
    if (_lightningAlpha > 0) _lightningAlpha = (_lightningAlpha - dt * 4.0).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;

    // Deep under-shadow grounds the storm cell.
    final underShadow = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 10), width: 92, height: 26), underShadow);

    // Volumetric puffs: each reads as a lit-capped billow sinking into shadow.
    final puffs = <Offset>[
      Offset(cx - 26, cy + 4),
      Offset(cx + 26, cy + 4),
      Offset(cx, cy),
    ];
    for (final p in puffs) {
      final r = (p == puffs.last) ? 28.0 : (p == puffs.first ? 22.0 : 20.0);
      final puffRect = Rect.fromCircle(center: p, radius: r);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.35),
            radius: 1.0,
            colors: const [Color(0xFF78909C), Color(0xFF37474F), Color(0xFF102027)],
            stops: const [0.0, .6, 1.0],
          ).createShader(puffRect),
      );
    }
    // Sunlit crests across the whole cloud top.
    final crest = Paint()..color = const Color(0x33FFFFFF);
    for (final p in puffs) {
      final cr = (p == puffs.last) ? 28.0 : (p == puffs.first ? 22.0 : 20.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(p.dx - 3, p.dy - cr * .6),
          width: cr * 1.1,
          height: cr * .45,
        ),
        crest,
      );
    }
    if (_stormCharged) {
      canvas.drawCircle(
        Offset(cx, cy),
        34 + math.sin(animTime * 9) * 3,
        Paint()
          ..color = ObstacleSynergy.stormCharge.color.withOpacity(.48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    if (_lightningAlpha > 0) {
      final bolt = Path()..moveTo(cx, cy + 10)..lineTo(cx - 5, cy + 28)..lineTo(cx + 6, cy + 34)..lineTo(cx, cy + 50);
      canvas.drawPath(bolt, Paint()..color = Color.fromRGBO(0, 229, 255, _lightningAlpha)..strokeWidth = 2.4..style = PaintingStyle.stroke);
    }
    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. KiteObstacle — Snap-Interactive Tether, Diamond Hitbox & Flowing Tail
// ─────────────────────────────────────────────────────────────────────────────

class KiteObstacle extends ObstacleComponent {
  KiteObstacle() : super(type: ObstacleType.kite);

  double _flutterPhase = 0;
  double _spawnX = 0;
  double _driftAmp = 50;
  double _snapHintStrength = 0;
  bool _windsockLinked = false;

  final TextPainter _snapPrompt = TextPainter(
    text: const TextSpan(
      text: 'SNAP',
      style: TextStyle(
        color: Color(0xFFB2EBF2),
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  Color get telegraphColor => const Color(0xFFFF4081);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(40, 110);
    _spawnX = position.x;
    _driftAmp = script?.driftAmp ?? rngRange(35, 65);
    _flutterPhase = rngRange(0, math.pi * 2);
    _snapHintStrength = 0;
    _windsockLinked = false;

    removeAll(children.whereType<ShapeHitbox>().toList());
    // Refined exact 4-point diamond PolygonHitbox.
    add(PolygonHitbox([
      Vector2(size.x * 0.5, 2),
      Vector2(size.x * 0.5 + 14, 20),
      Vector2(size.x * 0.5, 38),
      Vector2(size.x * 0.5 - 14, 20),
    ]));
  }

  @override
  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {
    _windsockLinked = synergy == ObstacleSynergy.windTether;
  }

  @override
  void updateObstacle(double dt) {
    final multiplier = _windsockLinked
        ? GameConfig.obstacleSynergyKiteDriftMultiplier
        : 1.0;
    _flutterPhase += dt * 3.5 * multiplier;
    position.x = (_spawnX +
            math.sin(_flutterPhase) *
                _driftAmp *
                multiplier *
                dynamicMovementFactor)
        .clamp(
          GameConfig.horizontalEdgeMargin + 20,
          GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 20,
        )
        .toDouble();
    _updateSnapHint(dt);
  }

  void _updateSnapHint(double dt) {
    // Precision Trials stay authored and do not surface optional shortcuts.
    final target = game.mode != GameMode.trial &&
            _isWithinSnapHintEnvelope(game.plane.position)
        ? 1.0
        : 0.0;
    final blend = (GameConfig.kiteTetherHintFadeRate * dt)
        .clamp(0.0, 1.0)
        .toDouble();
    _snapHintStrength = MathUtils.lerp(_snapHintStrength, target, blend);
  }

  bool _isWithinSnapHintEnvelope(Vector2 planePosition) {
    final dx = position.x - planePosition.x;
    final dy = position.y + 20.0 - planePosition.y;
    return dx.abs() <= GameConfig.kiteTetherHintHorizontalReach &&
        dy >= -GameConfig.kiteTetherHintReachAhead &&
        dy <= GameConfig.kiteTetherHintReachBehind;
  }

  @override
  double? snapInteractionDistanceSquaredTo(Vector2 planePosition) {
    if (!isActive || !type.isSnapInteractive) return null;
    final dx = position.x - planePosition.x;
    final dy = position.y + 20.0 - planePosition.y;
    if (dx.abs() > GameConfig.kiteTetherSnapHorizontalReach ||
        dy < -GameConfig.kiteTetherSnapReachAhead ||
        dy > GameConfig.kiteTetherSnapReachBehind) {
      return null;
    }
    return dx * dx + dy * dy;
  }

  @override
  bool resolveSnapInteraction(Vector2 planePosition) {
    if (snapInteractionDistanceSquaredTo(planePosition) == null) return false;

    final releasePosition = Vector2(position.x, position.y + 20.0);
    game.scoringSystem
        .awardComboNotches(GameConfig.kiteTetherSnapComboNotches);
    game.inputManager.restoreSnapCharge(GameConfig.kiteTetherSnapChargeRefund);
    game.collectibleSpawner.spawnCoinLine(
      x: releasePosition.x,
      startY: releasePosition.y,
      count: GameConfig.kiteTetherSnapRewardCoinCount,
      spacing: GameConfig.kiteTetherSnapRewardCoinSpacing,
    );
    game.world.add(
      ColoredBurst(
        position: releasePosition.clone(),
        color: const Color(0xFF80DEEA),
      ),
    );
    game.world.add(
      FloatingScoreText(
        position: releasePosition.clone(),
        text: 'TETHER CUT! +2 COMBO',
        color: const Color(0xFF80DEEA),
        fontSize: 15,
      ),
    );
    game.gameFeelSystem.onCoinCollected(game.scoringSystem.comboCount);
    recycleAfterInteraction();
    return true;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    const kiteY = 20.0;
    final tilt = math.sin(_flutterPhase) * 0.25;

    _drawTetherTail(canvas, cx, kiteY);
    if (_windsockLinked) {
      final windPaint = Paint()
        ..color = ObstacleSynergy.windTether.color.withOpacity(.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, kiteY + 22), width: 48, height: 32),
        animTime * 4.5,
        math.pi * 1.25,
        false,
        windPaint,
      );
    }

    canvas.save();
    canvas.translate(cx, kiteY);
    canvas.rotate(tilt);

    final kiteRect = Rect.fromLTWH(-16, -20, 32, 40);
    final topF = Path()
      ..moveTo(0, -18)
      ..lineTo(-14, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      topF,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8A80), Color(0xFFD32F2F)],
        ).createShader(kiteRect),
    );
    final rightF = Path()
      ..moveTo(0, -18)
      ..lineTo(14, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      rightF,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF80DEEA), Color(0xFF0097A7)],
        ).createShader(kiteRect),
    );
    final botLeftF = Path()
      ..moveTo(-14, 0)
      ..lineTo(0, 18)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      botLeftF,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFFEE58), Color(0xFFF9A825)],
        ).createShader(kiteRect),
    );
    final botRightF = Path()
      ..moveTo(14, 0)
      ..lineTo(0, 18)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      botRightF,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFB388FF), Color(0xFF651FFF)],
        ).createShader(kiteRect),
    );
    // Sunlit top-left sheen over the whole sail.
    final sheen = Path()
      ..moveTo(0, -18)
      ..lineTo(-14, 0)
      ..lineTo(0, 0)
      ..lineTo(14, 0)
      ..close();
    canvas.drawPath(sheen, Paint()..color = const Color(0x1FFFFFFF));
    // Fibreglass cross-frame.
    final frame = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -18), const Offset(0, 18), frame);
    canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), frame);

    canvas.restore();
    _drawSnapHint(canvas, cx, kiteY);
    renderTelegraph(canvas);
  }

  void _drawTetherTail(Canvas canvas, double cx, double kiteY) {
    final tailPaint = Paint()
      ..color = (_windsockLinked
              ? ObstacleSynergy.windTether.color
              : const Color(0xFF5D4037))
          .withOpacity(.74)
      ..strokeWidth = _windsockLinked ? 1.6 : 1.2
      ..strokeCap = StrokeCap.round;
    var previous = Offset(cx, kiteY + 18);
    for (var i = 0; i < 4; i++) {
      final y = kiteY + 34 + i * 16.0;
      final x = cx + math.sin(_flutterPhase + i * .9) * (5 + i * 2.0);
      final current = Offset(x, y);
      canvas.drawLine(previous, current, tailPaint);
      canvas.drawCircle(
        current,
        2.2,
        Paint()..color = i.isEven ? const Color(0xFFFFD740) : const Color(0xFF80DEEA),
      );
      previous = current;
    }
  }

  void _drawSnapHint(Canvas canvas, double cx, double kiteY) {
    final strength = _snapHintStrength;
    if (strength <= .02) return;
    final pulse = .75 + math.sin(_flutterPhase * 2.0) * .25;
    final ring = Paint()
      ..color = const Color(0xFF80DEEA).withOpacity(strength * .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final cut = Paint()
      ..color = const Color(0xFFE0F7FA).withOpacity(strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, kiteY), 24 + pulse * 3, ring);
    canvas.drawLine(Offset(cx - 8, kiteY - 7), Offset(cx + 8, kiteY + 7), cut);
    canvas.drawLine(Offset(cx - 8, kiteY + 7), Offset(cx + 8, kiteY - 7), cut);
    if (strength > .42) {
      _snapPrompt.paint(
        canvas,
        Offset(cx - _snapPrompt.width * .5, kiteY - 37),
      );
    }
  }
}

