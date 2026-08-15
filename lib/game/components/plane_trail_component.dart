import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';
import 'plane_component.dart';

/// Soft fading wispy ribbon that trails behind the paper plane.
///
/// Features:
///   - Trail wind interaction (trail bends and drifts with WindSystem lateral forces).
///   - Per-power-up dynamic color override (Turbo Dash flame, Ghost phasing cyan, Double Score fire, Coin Rush gold).
///   - Per-plane signature trail geometry:
///     - Stealth Jet: thin grey dashed supersonic wake (#90A4AE).
///     - Glider: double wavy wingtip vapor ribbons from port and starboard wingtips.
///   - Per-skin customized palettes plus plane+skin synergy particles (Petal Drift).
///   - Exposes [recentPositions] for Ghost after-image rendering.
class PlaneTrailComponent extends Component
    with HasGameRef<PaperFlightGame> {
  PlaneTrailComponent({required this.plane});

  final PositionComponent plane;

  final Queue<Vector2> _positions = Queue<Vector2>();
  final Queue<Vector2> _planePositions = Queue<Vector2>();
  double _sampleTimer = 0.0;
  double _animTime = 0.0;

  /// Exposes aircraft-centre history for Ghost after-image rendering. Trail
  /// geometry has a separate rear-fold emitter so these silhouettes stay
  /// aligned with the actual prior flight path.
  List<Vector2> get recentPositions => _planePositions.toList();

  @override
  void update(double dt) {
    if (gameRef.phase != GamePhase.playing) return;

    _animTime += dt;
    _sampleTimer += dt;
    if (_sampleTimer >= GameConfig.trailSampleInterval) {
      _sampleTimer = 0.0;
      // Emit from the rear fold rather than the component centre. This keeps
      // the newest trail segment behind the paper body instead of painting a
      // line across the aircraft when it banks sharply.
      final center = plane.absolutePosition.clone();
      final bank = plane.angle;
      final rearDirection = Vector2(-math.sin(bank), math.cos(bank));
      final emitter = center + rearDirection * (plane.size.y * .48);
      _positions.addLast(emitter);
      _planePositions.addLast(center);

      while (_positions.length > GameConfig.trailLength) {
        _positions.removeFirst();
      }
      while (_planePositions.length > GameConfig.trailLength) {
        _planePositions.removeFirst();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_positions.length < 2) return;

    final positions = _positions.toList();
    final count = positions.length;

    final parentPos = plane.position;
    final parentAngle = plane.angle;
    final halfW = plane.size.x / 2;
    final halfH = plane.size.y / 2;

    final PlaneComponent? pc = plane is PlaneComponent ? (plane as PlaneComponent) : null;
    final PaperSkin skin = pc?.paperSkin ?? PaperSkin.plain;
    final PlaneType pType = pc?.planeType ?? PlaneType.dart;
    final hasPetalTrail =
        pc?.skinSynergy.trailEffect == SkinTrailEffect.petals;

    final powerUps = gameRef.powerUpState;
    final bool isGhost = powerUps.ghostActive;
    final bool isDoubleScore = powerUps.doubleScoreActive;
    final bool isCoinRush = powerUps.coinRushActive;

    canvas.save();

    canvas.translate(halfW, halfH);
    canvas.rotate(-parentAngle);
    canvas.translate(-halfW, -halfH);
    canvas.translate(-parentPos.x + halfW, -parentPos.y + halfH);

    // ── Layered aerodynamic ribbons ─────────────────────────────────────────
    // Build wind-bent points once, then render each segment as a soft halo, a
    // coloured paper ribbon, and a fine highlight. Rounded quadratic joins
    // remove the old piecewise-straight, string-like appearance.
    if (pType == PlaneType.glider || pType == PlaneType.albatross) {
      for (final wingOffset in const [-16.0, 16.0]) {
        final adjusted = <Offset>[];
        for (var i = 0; i < count; i++) {
          final fraction = count <= 1 ? 1.0 : i / (count - 1);
          final point = positions[i];
          final wind = gameRef.windSystem.currentForceAt(point.x);
          final drift = wind * (1.0 - fraction) * .20;
          final wave = math.sin(_animTime * 5.4 + i * .42) * 2.1;
          adjusted.add(Offset(
            point.x + wingOffset + drift + wave,
            point.y,
          ));
        }

        for (var i = 1; i < adjusted.length; i++) {
          final fraction = i / (adjusted.length - 1);
          final color = isGhost
              ? const Color(0xFF00E5FF)
              : _getSegmentColor(skin, fraction, i);
          _drawRibbonSegment(
            canvas,
            adjusted,
            i,
            color: color,
            alpha: GameConfig.trailHeadAlpha * .88 * fraction,
            width: MathUtils.lerp(.45, 1.95, fraction),
          );
        }
      }
      canvas.restore();
      return;
    }

    final isStealth = pType == PlaneType.stealthJet;
    final adjusted = <Offset>[];
    for (var i = 0; i < count; i++) {
      final fraction = count <= 1 ? 1.0 : i / (count - 1);
      final point = positions[i];
      final wind = gameRef.windSystem.currentForceAt(point.x);
      final drift = wind * (1.0 - fraction) * .22;
      adjusted.add(Offset(point.x + drift, point.y));
    }

    for (var i = 1; i < adjusted.length; i++) {
      if (isStealth && i.isEven) continue;
      final fraction = i / (adjusted.length - 1);
      final Color color;
      if (isGhost) {
        color = const Color(0xFF00E5FF);
      } else if (isDoubleScore) {
        color = const Color(0xFFFF5722);
      } else if (isCoinRush) {
        color = const Color(0xFFFFD700);
      } else if (isStealth) {
        color = const Color(0xFF90A4AE);
      } else {
        color = _getSegmentColor(skin, fraction, i);
      }
      _drawRibbonSegment(
        canvas,
        adjusted,
        i,
        color: color,
        alpha: GameConfig.trailHeadAlpha * fraction,
        width: isStealth
            ? 1.35
            : MathUtils.lerp(
                GameConfig.trailTailWidth,
                GameConfig.trailHeadWidth,
                fraction,
              ),
        drawHighlight: !isStealth,
      );
    }

    if (hasPetalTrail) {
      _drawPetalTrail(canvas, positions);
    }

    canvas.restore();
  }

  void _drawRibbonSegment(
    Canvas canvas,
    List<Offset> points,
    int index, {
    required Color color,
    required double alpha,
    required double width,
    bool drawHighlight = true,
  }) {
    final previous = points[index - 1];
    final current = points[index];
    final start = index == 1
        ? previous
        : Offset(
            (previous.dx + current.dx) * .5,
            (previous.dy + current.dy) * .5,
          );
    final end = index == points.length - 1
        ? current
        : Offset(
            (current.dx + points[index + 1].dx) * .5,
            (current.dy + points[index + 1].dy) * .5,
          );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity((alpha * .24).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (drawHighlight && width > .8) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withOpacity((alpha * .34).clamp(0.0, .30))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.35, width * .24)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Butterfly + Cherry Blossom synergy: a handful of wind-carried petals
  /// drift through the existing trail history rather than spawning components
  /// every frame.
  void _drawPetalTrail(Canvas canvas, List<Vector2> positions) {
    final count = positions.length;
    final petalPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 1; i < count; i += 3) {
      final fraction = i / (count - 1);
      final point = positions[i];
      final wind = gameRef.windSystem.currentForceAt(point.x);
      final flutter = math.sin(_animTime * 8.0 + i * 1.7);
      final drift = wind * (1.0 - fraction) * .12;
      final alpha = (.10 + fraction * .48).clamp(0.0, .58).toDouble();
      petalPaint.color = Color.fromRGBO(244, 143, 177, alpha);

      canvas.save();
      canvas.translate(point.x + drift, point.y + flutter * 3.0);
      canvas.rotate(flutter * .55 + i * .3);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 3.5 + fraction * 3.2,
          height: 2.0 + fraction * 1.7,
        ),
        petalPaint,
      );
      canvas.restore();
    }
  }

  Color _getSegmentColor(PaperSkin skin, double headFraction, int index) {
    switch (skin) {
      case PaperSkin.plain:
        return const Color(0xFFFFFFFF);
      case PaperSkin.newspaper:
        return const Color(0xFFE8E0D0);
      case PaperSkin.goldLeaf:
        final sparkle = 0.85 + 0.15 * math.sin(_animTime * 12.0 + index * 0.8);
        return Color.lerp(const Color(0xFFFFD700), const Color(0xFFFFF9C4), sparkle)!;
      case PaperSkin.watercolorWash:
        final t = (math.sin(headFraction * math.pi * 3.0 + _animTime * 4.0) * 0.5 + 0.5);
        return Color.lerp(const Color(0xFF80DEEA), const Color(0xFFFF80AB), t)!;
      case PaperSkin.holographicFoil:
      case PaperSkin.animatedHologram:
      case PaperSkin.flipbook:
        final hue = (headFraction * 260.0 + _animTime * 90.0) % 360.0;
        return HSLColor.fromAHSL(1.0, hue, 0.85, 0.65).toColor();
      case PaperSkin.prideGradient:
        const rainbow = [
          Color(0xFFFF1744),
          Color(0xFFFF9100),
          Color(0xFFFFEA00),
          Color(0xFF00E676),
          Color(0xFF2979FF),
          Color(0xFFAA00FF),
        ];
        return rainbow[(index + (_animTime * 8.0).toInt()) % rainbow.length];
      case PaperSkin.blueprint:
        return const Color(0xFF00E5FF);
      case PaperSkin.receipt:
        return const Color(0xFFE0E0E0);
      case PaperSkin.carbonFiber:
        return const Color(0xFF616161);
      case PaperSkin.mangaHalftone:
        return (index % 2 == 0) ? const Color(0xFFFFFFFF) : const Color(0xFF212121);
      case PaperSkin.kraftEnvelope:
        return const Color(0xFFD7CCC8);
      case PaperSkin.dragonScales:
        final t = (math.sin(_animTime * 6.0 + index) * 0.5 + 0.5);
        return Color.lerp(const Color(0xFF00E676), const Color(0xFFFFD600), t)!;
      case PaperSkin.snowflake:
        return const Color(0xFF80D8FF);
      case PaperSkin.pumpkin:
        return const Color(0xFFFF6D00);
      case PaperSkin.cherryBlossom:
        return const Color(0xFFF48FB1);
      case PaperSkin.lavaLamp:
        final t = (math.sin(_animTime * 3.5 + index * 0.5) * 0.5 + 0.5);
        return Color.lerp(const Color(0xFFE040FB), const Color(0xFF00E5FF), t)!;
      case PaperSkin.graphPaper:
        return const Color(0xFF0288D1);
      case PaperSkin.notebookDoodle:
        return const Color(0xFF4FC3F7);
      case PaperSkin.customCraft:
        return const Color(0xFF80D8FF);
    }
  }

  void clear() {
    _positions.clear();
    _planePositions.clear();
    _sampleTimer = 0.0;
  }
}
