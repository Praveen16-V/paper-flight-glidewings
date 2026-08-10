import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../../providers/game_session_provider.dart';
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
///   - Per-skin customized palettes.
///   - Exposes [recentPositions] for Ghost after-image rendering.
class PlaneTrailComponent extends Component
    with HasGameRef<PaperFlightGame> {
  PlaneTrailComponent({required this.plane});

  final PositionComponent plane;

  final Queue<Vector2> _positions = Queue<Vector2>();
  double _sampleTimer = 0.0;
  double _animTime = 0.0;

  /// Exposes recorded trail positions for Ghost after-image rendering.
  List<Vector2> get recentPositions => _positions.toList();

  @override
  void update(double dt) {
    if (gameRef.phase != GamePhase.playing) return;

    _animTime += dt;
    _sampleTimer += dt;
    if (_sampleTimer >= GameConfig.trailSampleInterval) {
      _sampleTimer = 0.0;
      _positions.addLast(plane.absolutePosition.clone());

      while (_positions.length > GameConfig.trailLength) {
        _positions.removeFirst();
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

    final session = gameRef.ref.read(gameSessionProvider);
    final bool isTurboDash = session.activePowerUps.contains(PowerUpType.turboDash);
    final bool isGhost = session.activePowerUps.contains(PowerUpType.ghost);
    final bool isDoubleScore = session.activePowerUps.contains(PowerUpType.doubleScore);
    final bool isCoinRush = session.activePowerUps.contains(PowerUpType.coinRush);

    canvas.save();

    canvas.translate(halfW, halfH);
    canvas.rotate(-parentAngle);
    canvas.translate(-halfW, -halfH);
    canvas.translate(-parentPos.x + halfW, -parentPos.y + halfH);

    // ── 1. Glider Double Wingtip Vapor Trails ────────────────────────────────
    if (pType == PlaneType.glider || pType == PlaneType.albatross) {
      for (final wingOffset in [-16.0, 16.0]) {
        for (int i = 1; i < count; i++) {
          final headFraction = i / (count - 1);
          final alpha = (GameConfig.trailHeadAlpha * 0.85 * headFraction).clamp(0.0, 1.0);
          final wave = math.sin(_animTime * 6.0 + i * 0.4) * 2.0;

          // Trail wind interaction
          final normX = (positions[i].x / GameConfig.designWidth).clamp(0.0, 1.0);
          final lane = gameRef.windSystem.laneForNormX(normX);
          final wind = gameRef.windSystem.windAt(lane);
          final windDrift = wind.lateralForce * (1.0 - headFraction) * 0.20;

          final Color segColor = isTurboDash
              ? const Color(0xFFFF5722)
              : (isGhost
                  ? const Color(0xFF00E5FF)
                  : _getSegmentColor(skin, headFraction, i));

          final paint = Paint()
            ..color = segColor.withOpacity(alpha)
            ..strokeWidth = MathUtils.lerp(0.4, 1.8, headFraction)
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;

          final p1 = Offset(positions[i - 1].x + wingOffset + wave + windDrift, positions[i - 1].y);
          final p2 = Offset(positions[i].x + wingOffset + wave + windDrift, positions[i].y);
          canvas.drawLine(p1, p2, paint);
        }
      }
      canvas.restore();
      return;
    }

    // ── 2. Standard & Stealth Jet Trail ──────────────────────────────────────
    final isStealth = pType == PlaneType.stealthJet;

    for (int i = 1; i < count; i++) {
      if (isStealth && i % 2 == 0) continue;

      final headFraction = i / (count - 1);
      final alpha = (GameConfig.trailHeadAlpha * headFraction).clamp(0.0, 1.0);
      final strokeWidth = isStealth
          ? 1.4
          : MathUtils.lerp(
              GameConfig.trailTailWidth,
              GameConfig.trailHeadWidth,
              headFraction,
            );

      // Trail wind interaction
      final normX = (positions[i].x / GameConfig.designWidth).clamp(0.0, 1.0);
      final lane = gameRef.windSystem.laneForNormX(normX);
      final wind = gameRef.windSystem.windAt(lane);
      final windDrift = wind.lateralForce * (1.0 - headFraction) * 0.22;

      final Color segColor;
      if (isTurboDash) {
        segColor = (i % 2 == 0) ? const Color(0xFFFF3D00) : const Color(0xFFFFD54F);
      } else if (isGhost) {
        segColor = const Color(0xFF00E5FF);
      } else if (isDoubleScore) {
        segColor = const Color(0xFFFF5722);
      } else if (isCoinRush) {
        segColor = const Color(0xFFFFD700);
      } else if (isStealth) {
        segColor = const Color(0xFF90A4AE);
      } else {
        segColor = _getSegmentColor(skin, headFraction, i);
      }

      final paint = Paint()
        ..color = segColor.withOpacity(alpha)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(positions[i - 1].x + windDrift, positions[i - 1].y),
        Offset(positions[i].x + windDrift, positions[i].y),
        paint,
      );
    }

    canvas.restore();
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
    _sampleTimer = 0.0;
  }
}
