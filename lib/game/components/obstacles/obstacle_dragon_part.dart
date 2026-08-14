// Part of the obstacle library — see obstacle_component.dart for the
// shared base class and imports.
part of 'obstacle_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 20. PaperDragonObstacle — Segmented Serpentine Boss Pass
// ─────────────────────────────────────────────────────────────────────────────

/// A single high-readability boss encounter. The dragon is assembled from
/// collision circles which follow one animated S-curve; the circles and their
/// segment state are retained with the pooled obstacle, so an encounter does
/// not allocate a fresh component tree every frame or every reuse.
class PaperDragonObstacle extends ObstacleComponent {
  PaperDragonObstacle() : super(type: ObstacleType.paperDragon);

  static const int segmentCount = GameConfig.paperDragonSegmentCount;

  final List<_PaperDragonSegment> _segments =
      List<_PaperDragonSegment>.generate(
    segmentCount,
    _PaperDragonSegment.new,
    growable: false,
  );
  final List<CircleHitbox> _segmentHitboxes = <CircleHitbox>[];

  final Paint _spineGlowPaint = Paint()
    ..color = const Color(0x66FF5252)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8.0
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
  final Paint _spinePaint = Paint()
    ..color = const Color(0xFF6D1838)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.2
    ..strokeCap = StrokeCap.round;
  final Paint _bodyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _bodyCorePaint = Paint()
    ..color = const Color(0xFF8E244B)
    ..style = PaintingStyle.fill;
  final Paint _bodyFoldPaint = Paint()
    ..color = const Color(0xFFFFCDD2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.15;
  final Paint _wingPaint = Paint()
    ..color = const Color(0xFF7B1B41)
    ..style = PaintingStyle.fill;
  final Paint _wingFoldPaint = Paint()
    ..color = const Color(0xFFFF8A80)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _headPaint = Paint()
    ..color = const Color(0xFFC62858)
    ..style = PaintingStyle.fill;
  final Paint _headFoldPaint = Paint()
    ..color = const Color(0xFFFFCDD2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.35;
  final Paint _hornPaint = Paint()
    ..color = const Color(0xFFFFF3E0)
    ..style = PaintingStyle.fill;
  final Paint _eyeGlowPaint = Paint()
    ..color = const Color(0x99FFAB00)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  final Paint _eyePaint = Paint()
    ..color = const Color(0xFFFFF176)
    ..style = PaintingStyle.fill;
  final Paint _pupilPaint = Paint()
    ..color = const Color(0xFF1A0610)
    ..style = PaintingStyle.fill;
  final Paint _mouthPaint = Paint()
    ..color = const Color(0xFFFFAB40)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2.2;
  final Paint _previewGlowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
  final Paint _previewBodyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _previewCrownPaint = Paint()..style = PaintingStyle.fill;

  final TextPainter _bossLabel = TextPainter(
    text: const TextSpan(
      text: 'PAPER DRAGON',
      style: TextStyle(
        color: Color(0xFFFFCDD2),
        fontSize: 8.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double _waveSeed = 0.0;
  double _headSeed = 0.0;

  @override
  Color get telegraphColor => const Color(0xFFFF5252);

  @override
  double get earlyWarningLeadDistance =>
      GameConfig.paperDragonTelegraphLeadDistance;

  @override
  bool get retainsHitboxesWhenInactive => true;

  /// Useful to instrumentation and lightweight component tests without
  /// exposing the mutable hitbox list itself.
  int get segmentHitboxCount => _segmentHitboxes.length;
  int get activeSegmentCount => _segments.length;

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(
      GameConfig.designWidth,
      GameConfig.paperDragonBodyHeight,
    );
    // A boss owns the full width. Keep the component anchored at the world
    // centre regardless of the random lane supplied by the regular spawner.
    position.x = GameConfig.designWidth * .5;
    _waveSeed = rngRange(0.0, math.pi * 2.0);
    _headSeed = rngRange(0.0, math.pi * 2.0);
    _ensureSegmentHitboxes();
    _syncSegmentGeometry();
  }

  void _ensureSegmentHitboxes() {
    if (_segmentHitboxes.isEmpty) {
      for (var i = 0; i < segmentCount; i++) {
        final hitbox = CircleHitbox(
          radius: GameConfig.paperDragonHitboxRadius,
          position: Vector2.zero(),
        );
        _segmentHitboxes.add(hitbox);
        add(hitbox);
      }
      return;
    }

    // A Flame parent can be removed and mounted again by the object pool. Keep
    // the same collision components, but reattach them if that lifecycle pass
    // detached children from the parent.
    for (final hitbox in _segmentHitboxes) {
      if (hitbox.parent == null) add(hitbox);
    }
  }

  @override
  void updateObstacle(double dt) {
    // The base component already applies full world scroll. Pulling back the
    // remainder creates the configured slow, deliberate boss pass.
    position.y -= game.scrollSpeed *
        dt *
        (1.0 - GameConfig.paperDragonScrollSpeedMultiplier);
    _syncSegmentGeometry();
  }

  void _syncSegmentGeometry() {
    final lastIndex = _segments.length - 1;
    final waveTime =
        _waveSeed + animTime * GameConfig.paperDragonWaveAngularSpeed;
    final headWander = math.sin(
          _headSeed + animTime * GameConfig.paperDragonHeadWanderAngularSpeed,
        ) *
        GameConfig.paperDragonHeadWanderAmplitude;

    for (var i = 0; i <= lastIndex; i++) {
      final progress = i / lastIndex;
      final waveEnvelope = 1.0 -
          (1.0 - GameConfig.paperDragonWaveTailAmplitudeMultiplier) *
              progress;
      final x = GameConfig.designWidth * .5 +
          headWander +
          math.sin(
                waveTime + i * GameConfig.paperDragonWavePhaseStep,
              ) *
              GameConfig.paperDragonWaveAmplitude *
              waveEnvelope;
      final y = GameConfig.paperDragonHeadOffsetY +
          i * GameConfig.paperDragonSegmentSpacing;
      final segment = _segments[i];
      segment.center.setValues(x, y);
      segment.scale =
          1.0 - (1.0 - GameConfig.paperDragonTailScale) * progress;

      final hitbox = _segmentHitboxes[i];
      final radius = GameConfig.paperDragonHitboxRadius;
      hitbox.position.setValues(x - radius, y - radius);
    }

    // The head faces against the flow of the body; all other segments align to
    // their local tangent so the folded scales travel around the S cleanly.
    final head = _segments.first;
    final neck = _segments[1];
    head.heading = math.atan2(
      head.center.y - neck.center.y,
      head.center.x - neck.center.x,
    );
    for (var i = 1; i <= lastIndex; i++) {
      final previous = _segments[i - 1];
      final current = _segments[i];
      final next = i == lastIndex ? current : _segments[i + 1];
      current.heading = math.atan2(
        next.center.y - previous.center.y,
        next.center.x - previous.center.x,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    _drawSpine(canvas);
    for (var i = _segments.length - 1; i >= 1; i--) {
      _drawBodySegment(canvas, _segments[i]);
    }
    _drawHead(canvas, _segments.first);
    renderTelegraph(canvas);
  }

  void _drawSpine(Canvas canvas) {
    for (var i = 0; i < _segments.length - 1; i++) {
      final from = _segments[i].center;
      final to = _segments[i + 1].center;
      final start = Offset(from.x, from.y);
      final end = Offset(to.x, to.y);
      canvas.drawLine(start, end, _spineGlowPaint);
      canvas.drawLine(start, end, _spinePaint);
    }
  }

  void _drawBodySegment(Canvas canvas, _PaperDragonSegment segment) {
    final radius = GameConfig.paperDragonSegmentRadius * segment.scale;
    final base = segment.index.isEven
        ? const Color(0xFFA5274F)
        : const Color(0xFFB92B56);
    _bodyPaint.color = base;

    canvas.save();
    canvas.translate(segment.center.x, segment.center.y);
    canvas.rotate(segment.heading);
    final segRect =
        Rect.fromCenter(center: Offset.zero, width: radius * 2.35, height: radius * 1.58);
    canvas.drawOval(
      segRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.7),
          radius: 1.1,
          colors: [Color.lerp(base, Colors.white, .28)!, base, Color.lerp(base, Colors.black, .42)!],
          stops: const [0.0, .5, 1.0],
        ).createShader(segRect),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 1.18,
        height: radius * .82,
      ),
      _bodyCorePaint,
    );
    // Two crease lines keep every oval visibly folded like layered paper.
    canvas.drawLine(
      Offset(-radius * .78, 0),
      Offset(radius * .76, 0),
      _bodyFoldPaint,
    );
    canvas.drawLine(
      Offset(-radius * .22, -radius * .56),
      Offset(radius * .28, radius * .48),
      _bodyFoldPaint,
    );
    // Glossy specular sweep along the top of each scale.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-radius * .1, -radius * .42),
        width: radius * 1.7,
        height: radius * .42,
      ),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.restore();
  }

  void _drawHead(Canvas canvas, _PaperDragonSegment head) {
    final pulse = .86 + math.sin(animTime * 7.0) * .14;

    canvas.save();
    canvas.translate(head.center.x, head.center.y);
    canvas.rotate(head.heading);
    canvas.scale(pulse);

    // Broad angular wings are drawn first, so the faceted head remains the
    // readable collision focal point at the front of the serpent.
    canvas.drawPath(_leftWingPath, _wingPaint);
    canvas.drawPath(_rightWingPath, _wingPaint);
    canvas.drawPath(_leftWingPath, _wingFoldPaint);
    canvas.drawPath(_rightWingPath, _wingFoldPaint);
    canvas.drawPath(_headPath, _headPaint);
    canvas.drawPath(_headFoldPath, _headFoldPaint);
    canvas.drawPath(_hornPath, _hornPaint);

    canvas.drawCircle(const Offset(11, -6), 5.6, _eyeGlowPaint);
    canvas.drawCircle(const Offset(11, -6), 2.45, _eyePaint);
    canvas.drawCircle(const Offset(11.6, -6), 1.0, _pupilPaint);
    canvas.drawCircle(const Offset(11, 6), 5.6, _eyeGlowPaint);
    canvas.drawCircle(const Offset(11, 6), 2.45, _eyePaint);
    canvas.drawCircle(const Offset(11.6, 6), 1.0, _pupilPaint);

    canvas.drawLine(const Offset(12, 9), const Offset(25, 9), _mouthPaint);
    final flameLength = 9.0 + math.sin(animTime * 11.0) * 5.0;
    canvas.drawLine(Offset(24, 9), Offset(24 + flameLength, 9), _mouthPaint);
    canvas.restore();
  }

  @override
  void renderThreatPreview(
    Canvas canvas,
    double x,
    double y,
    double progress,
    double pulse,
  ) {
    // The generic beacon identifies the lane. This wider mini-serpent and
    // label make it unambiguously different from a normal off-screen hazard.
    if (progress < .12) return;

    final alpha = ((progress - .12) / .88).clamp(.0, 1.0).toDouble();
    _previewGlowPaint.color = const Color(0x88FF1744).withOpacity(.44 * alpha);
    _previewBodyPaint.color = const Color(0xFFFF5252).withOpacity(.72 * alpha);
    _previewCrownPaint.color = const Color(0xFFFFD740).withOpacity(.82 * alpha);

    canvas.save();
    canvas.translate(x, y + 34);
    canvas.drawCircle(Offset.zero, 42 + pulse * 4, _previewGlowPaint);
    for (var i = 0; i < 5; i++) {
      final px = -40.0 + i * 20.0;
      final py = math.sin(animTime * 4.0 + i * .92) * 6.0;
      canvas.drawCircle(Offset(px, py), i == 4 ? 8.0 : 6.0, _previewBodyPaint);
    }
    canvas.drawPath(_previewCrownPath, _previewCrownPaint);
    if (progress > .46) {
      _bossLabel.paint(
        canvas,
        Offset(-_bossLabel.width * .5, 17),
      );
    }
    canvas.restore();
  }

  static final Path _leftWingPath = Path()
    ..moveTo(-4, -4)
    ..lineTo(-29, -35)
    ..lineTo(-19, -2)
    ..lineTo(-8, 6)
    ..close();
  static final Path _rightWingPath = Path()
    ..moveTo(-4, 4)
    ..lineTo(-29, 35)
    ..lineTo(-19, 2)
    ..lineTo(-8, -6)
    ..close();
  static final Path _headPath = Path()
    ..moveTo(29, 0)
    ..lineTo(6, -19)
    ..lineTo(-20, -13)
    ..lineTo(-25, 0)
    ..lineTo(-20, 13)
    ..lineTo(6, 19)
    ..close();
  static final Path _headFoldPath = Path()
    ..moveTo(-20, -13)
    ..lineTo(6, 0)
    ..lineTo(-20, 13)
    ..moveTo(6, -19)
    ..lineTo(6, 19)
    ..moveTo(6, 0)
    ..lineTo(29, 0);
  static final Path _hornPath = Path()
    ..moveTo(-6, -14)
    ..lineTo(-1, -27)
    ..lineTo(4, -13)
    ..close()
    ..moveTo(-6, 14)
    ..lineTo(-1, 27)
    ..lineTo(4, 13)
    ..close();
  static final Path _previewCrownPath = Path()
    ..moveTo(24, -8)
    ..lineTo(29, -21)
    ..lineTo(34, -9)
    ..lineTo(39, -24)
    ..lineTo(44, -8)
    ..close();
}

class _PaperDragonSegment {
  _PaperDragonSegment(this.index);

  final int index;
  final Vector2 center = Vector2.zero();
  double heading = 0.0;
  double scale = 1.0;
}
