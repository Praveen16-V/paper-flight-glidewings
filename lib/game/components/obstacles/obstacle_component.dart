import 'dart:async';
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
import '../../../providers/game_session_provider.dart';
import '../../paper_flight_game.dart';
import '../plane_component.dart';
import 'obstacle_script.dart';

/// Base class for all obstacle types.
abstract class ObstacleComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  ObstacleComponent({required this.type}) : super(anchor: Anchor.topCenter);

  final ObstacleType type;

  bool _active = false;
  bool get isActive => _active;
  bool _nearMissAwarded = false;

  double _minNearMissClearance = double.infinity;
  void Function(ObstacleComponent)? onRecycle;

  double? safeCorridorX;
  ObstacleScript? script;
  late math.Random _rng;

  double rngRange(double min, double max) =>
      min + _rng.nextDouble() * (max - min);

  int rngInt(int min, int max) => min + _rng.nextInt(max - min + 1);

  bool rngBool() => _rng.nextBool();

  double animTime = 0.0;
  bool challengeGapCounted = false;

  bool get hasTelegraph => true;
  Color get telegraphColor => const Color(0xFFFF9800);

  // ── Activation ─────────────────────────────────────────────────────────────

  void activate({
    required double spawnX,
    required double scrollSpeed,
    double? safeCorridorX,
    void Function(ObstacleComponent)? recycleCallback,
    ObstacleScript? script,
    math.Random? rng,
  }) {
    final earlyWarning = type == ObstacleType.drone ||
        type == ObstacleType.bird ||
        type == ObstacleType.stormCloud ||
        type == ObstacleType.trafficPlane ||
        type == ObstacleType.fireworks;
    position = Vector2(spawnX, earlyWarning ? -260 : GameConfig.obstacleSpawnY);
    _active = true;
    _nearMissAwarded = false;
    _minNearMissClearance = double.infinity;
    animTime = 0.0;
    challengeGapCounted = false;
    onRecycle = recycleCallback;
    this.safeCorridorX = safeCorridorX;
    this.script = script;
    _rng = rng ?? math.Random();
    onActivate(scrollSpeed);
    _playThreatCue();
  }

  void deactivate() {
    _active = false;
    onRecycle = null;
    safeCorridorX = null;
    script = null;
    _nearMissAwarded = false;
    _minNearMissClearance = double.infinity;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  /// Shield Lv2 can reflect projectile-class hazards. Recycling through the
  /// original callback preserves object-pool ownership and avoids a duplicate
  /// collision on the next frame.
  void deflectByShield() {
    if (!_active) return;
    _active = false;
    onRecycle?.call(this);
  }

  void onActivate(double scrollSpeed) {}

  void _playThreatCue() {
    final cue = switch (type) {
      ObstacleType.drone => 'drone_warning.wav',
      ObstacleType.bird => 'bird_warning.wav',
      ObstacleType.stormCloud => 'thunder_warning.wav',
      _ => null,
    };
    if (cue != null) {
      final rate = switch (type) {
        ObstacleType.drone => 1.30,
        ObstacleType.bird => 1.15,
        ObstacleType.stormCloud => 0.72,
        _ => 1.0,
      };
      unawaited(_playThreatCueAsync(cue, rate));
    }
  }

  Future<void> _playThreatCueAsync(String cue, double rate) async {
    try {
      await FlameAudio.play(cue, volume: .32);
    } catch (_) {}
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_active) return;

    animTime += dt;
    position.y += game.scrollSpeed * dt;

    updateObstacle(dt);
    _trackNearMiss();

    if (position.y > GameConfig.obstacleRecycleY) {
      _active = false;
      onRecycle?.call(this);
    }

    super.update(dt);
  }

  void updateObstacle(double dt) {}

  double get dynamicMovementFactor {
    if (game.mode == GameMode.trial) return 1.0;
    final meters = game.distanceMeters;
    if (meters <= GameConfig.dynamicObstacleRampStartMeters) return 0.0;
    if (meters >= GameConfig.dynamicObstacleRampEndMeters) return 1.0;
    return ((meters - GameConfig.dynamicObstacleRampStartMeters) /
            (GameConfig.dynamicObstacleRampEndMeters -
                GameConfig.dynamicObstacleRampStartMeters))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  // ── Collision ──────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (!_active) return;
    if (other is PlaneComponent) {
      _nearMissAwarded = true;
      game.onPlaneCrash(obstacleType: type, obstacle: this);
    }
  }

  // ── Tiered Near-Miss ───────────────────────────────────────────────────────

  void _trackNearMiss() {
    if (_nearMissAwarded) return;
    if (game.phase != GamePhase.playing) return;

    try {
      final session = game.ref.read(gameSessionProvider);
      if (session.activePowerUps.contains(PowerUpType.ghost)) return;
    } catch (_) {}

    final plane = game.plane;
    final myCenterY = position.y + size.y * 0.5;
    if ((myCenterY - plane.position.y).abs() > GameConfig.designHeight * 0.55) {
      return;
    }

    final clearance = _clearanceToPlane();
    if (clearance < _minNearMissClearance) {
      _minNearMissClearance = clearance;
    }

    final tier = nearMissTierForClearance(_minNearMissClearance);
    if (tier != null) {
      final settling =
          clearance > _minNearMissClearance + GameConfig.nearMissSettleSlop;
      final passedBelow = position.y > plane.position.y + plane.size.y;
      if (settling || passedBelow) {
        _nearMissAwarded = true;

        // Golden Bird elite: 3x points and bonus coins!
        if (this is BirdObstacle && (this as BirdObstacle).isGolden) {
          game.scoringSystem.onNearMiss(
            position: plane.position.clone(),
            tier: tier,
          );
          game.scoringSystem.onCoinCollected();
          game.scoringSystem.onCoinCollected();
        } else {
          game.scoringSystem.onNearMiss(
            position: plane.position.clone(),
            tier: tier,
          );
        }
      }
    } else if (position.y > plane.position.y + size.y + 60) {
      _nearMissAwarded = true;
    }
  }

  double _clearanceToPlane() {
    final planeRect = game.plane.worldAabbRect;
    var best = double.infinity;
    for (final hitbox in children.whereType<ShapeHitbox>()) {
      final aabb = hitbox.aabb;
      final dx = aabb.min.x > planeRect.right
          ? aabb.min.x - planeRect.right
          : planeRect.left > aabb.max.x
              ? planeRect.left - aabb.max.x
              : 0.0;
      final dy = aabb.min.y > planeRect.bottom
          ? aabb.min.y - planeRect.bottom
          : planeRect.top > aabb.max.y
              ? planeRect.top - aabb.max.y
              : 0.0;
      final gap = math.sqrt(dx * dx + dy * dy);
      if (gap < best) best = gap;
    }
    return best;
  }

  // ── Off-screen Telegraph Rendering ─────────────────────────────────────────

  void renderTelegraph(Canvas canvas) {
    if (!hasTelegraph || !_active || position.y >= 0 || position.y < -260) {
      return;
    }

    final progress = (1.0 - (position.y.abs() / 260.0)).clamp(0.0, 1.0);
    final pulse = (math.sin(animTime * 14.0) * 0.5 + 0.5);
    final alpha = (progress * (0.65 + 0.35 * pulse)).clamp(0.0, 1.0);

    final warningPaint = Paint()
      ..color = telegraphColor.withOpacity(alpha)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = telegraphColor.withOpacity(alpha * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final beaconX =
        position.x.clamp(32.0, GameConfig.designWidth - 32.0).toDouble();
    const beaconY = 18.0;
    final localX = beaconX - position.x;
    final localY = beaconY - position.y;

    canvas.save();
    canvas.translate(localX, localY);

    canvas.drawCircle(Offset.zero, 14, glowPaint);

    final badgePath = Path()
      ..moveTo(0, -12)
      ..lineTo(11, 0)
      ..lineTo(0, 12)
      ..lineTo(-11, 0)
      ..close();
    canvas.drawPath(badgePath, warningPaint);

    final innerPaint = Paint()
      ..color = const Color(0xFF1A1A24)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.5, -7, 3, 7.5),
        const Radius.circular(1),
      ),
      innerPaint,
    );
    canvas.drawCircle(const Offset(0, 3.5), 1.6, innerPaint);

    final chevronY = 15.0 + pulse * 3.0;
    final chevronPath = Path()
      ..moveTo(-6, chevronY)
      ..lineTo(0, chevronY + 6)
      ..lineTo(6, chevronY)
      ..lineTo(4.5, chevronY)
      ..lineTo(0, chevronY + 4.5)
      ..lineTo(-4.5, chevronY)
      ..close();
    canvas.drawPath(chevronPath, warningPaint);

    canvas.restore();
    renderThreatPreview(canvas, localX, localY, progress, pulse);
  }

  void renderThreatPreview(
      Canvas canvas, double x, double y, double progress, double pulse) {}
}

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
    _sparkTimer -= dt;
    if (_sparkTimer <= 0) {
      _sparkTimer = MathUtils.randomRange(1.8, 3.5);
      _sparkAlpha = 1.0;
      _sparkOnLeft = math.Random().nextBool();
      if (_sparkOnLeft) {
        _sparkX = MathUtils.randomRange(25, math.max(30, _gapX - 15));
      } else {
        final rightStart = _gapX + _gapWidth;
        _sparkX = MathUtils.randomRange(
            rightStart + 15, GameConfig.designWidth - 25);
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

    // Check if Magnet power-up is active (sparks chain continuously!)
    bool magnetChaining = false;
    try {
      final session = gameRef.ref.read(gameSessionProvider);
      magnetChaining = session.activePowerUps.contains(PowerUpType.magnet);
    } catch (_) {}

    _drawPylonTower(canvas, 0, h);
    _drawPylonTower(canvas, w - 16, h);

    final wirePaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final wireHighlight = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final sagOffsets = [8.0, 16.0, 24.0];
    for (int i = 0; i < sagOffsets.length; i++) {
      final yOff = sagOffsets[i];
      final sagAmount = 5.0 + i * 1.5;

      final leftPath = Path()
        ..moveTo(14, yOff)
        ..quadraticBezierTo(
            _gapX * 0.5, yOff + sagAmount, _gapX, yOff + sagAmount * 0.5);
      canvas.drawPath(leftPath, wirePaint);
      canvas.drawPath(leftPath, wireHighlight);

      final rightSpan = w - 14 - rightStart;
      final rightPath = Path()
        ..moveTo(rightStart, yOff + sagAmount * 0.5)
        ..quadraticBezierTo(
            rightStart + rightSpan * 0.5, yOff + sagAmount, w - 14, yOff);
      canvas.drawPath(rightPath, wirePaint);
      canvas.drawPath(rightPath, wireHighlight);

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

  void _drawPylonTower(Canvas canvas, double x, double h) {
    final steelPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.fill;
    final trussPaint = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(x + 4, 0, 8, h), steelPaint);
    canvas.drawRect(Rect.fromLTWH(x, 6, 16, 4), steelPaint);
    canvas.drawRect(Rect.fromLTWH(x, 14, 16, 4), steelPaint);
    canvas.drawRect(Rect.fromLTWH(x, 22, 16, 4), steelPaint);

    canvas.drawLine(Offset(x + 4, 6), Offset(x + 12, 14), trussPaint);
    canvas.drawLine(Offset(x + 12, 14), Offset(x + 4, 22), trussPaint);

    final insulatorPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x + 2, 8), 2.2, insulatorPaint);
    canvas.drawCircle(Offset(x + 14, 8), 2.2, insulatorPaint);
    canvas.drawCircle(Offset(x + 2, 16), 2.2, insulatorPaint);
    canvas.drawCircle(Offset(x + 14, 16), 2.2, insulatorPaint);
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

  void _drawBuildingTower(
      Canvas canvas, double startX, double bw, double bh,
      {required bool isLeft}) {
    if (bw <= 0) return;

    // Biome-specific facade color tinting
    final Biome currentBiome = gameRef.biomeManager.currentBiome;
    final Color facadeColor = switch (currentBiome) {
      Biome.city => const Color(0xFF78909C),       // cool blue-grey skyscraper
      Biome.storm => const Color(0xFF37474F),      // dark storm-worn slate
      Biome.night => const Color(0xFF1A237E),      // midnight navy noir
      Biome.atmosphere => const Color(0xFF263238), // high-altitude carbon
      _ => const Color(0xFFD7B98C),                // warm kraft tan
    };
    final Color foldColor = Color.lerp(facadeColor, const Color(0xFF000000), 0.25)!;
    final Color trimColor = Color.lerp(facadeColor, const Color(0xFF000000), 0.40)!;
    final Color outlineColor = Color.lerp(facadeColor, const Color(0xFF000000), 0.60)!;

    final facadePaint = Paint()..color = facadeColor..style = PaintingStyle.fill;
    final foldEdgePaint = Paint()..color = foldColor..style = PaintingStyle.fill;
    final trimPaint = Paint()..color = trimColor..style = PaintingStyle.fill;
    final outlinePaint = Paint()..color = outlineColor..style = PaintingStyle.stroke..strokeWidth = 1.6;

    canvas.drawRect(Rect.fromLTWH(startX, 0, bw, bh), facadePaint);
    canvas.drawRect(Rect.fromLTWH(startX, 0, bw, bh), outlinePaint);

    final sideWidth = math.min(10.0, bw * 0.2);
    if (isLeft) {
      canvas.drawRect(
          Rect.fromLTWH(startX + bw - sideWidth, 0, sideWidth, bh),
          foldEdgePaint);
    } else {
      canvas.drawRect(
          Rect.fromLTWH(startX, 0, sideWidth, bh), foldEdgePaint);
    }

    canvas.drawRect(Rect.fromLTWH(startX, 0, bw, 8), trimPaint);
    canvas.drawRect(Rect.fromLTWH(startX, bh * 0.5, bw, 4), trimPaint);

    // Optimized Batched Window Rendering
    _drawBatchedLitWindows(canvas, startX + (isLeft ? 6 : sideWidth + 4),
        bw - sideWidth - 10, bh);

    // Rooftop Features & Environmental Storytelling Billboards
    if (bw > 45) {
      if (_style == 0) {
        _drawHvacFan(canvas, startX + bw * 0.4, 0);
        _drawRooftopBillboard(canvas, startX + bw * 0.5, 0, isLeft);
      } else if (_style == 1 && isLeft) {
        _drawWaterTower(canvas, startX + bw * 0.35, 0);
      } else {
        _drawAntennaSpire(canvas, startX + bw * 0.5, 0);
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

    final warmPath = Path();
    final cyanPath = Path();
    final darkPath = Path();

    for (double x = startX; x < startX + usableW - winW; x += colGap) {
      for (double y = 16.0; y < bh - winH - 8; y += rowGap) {
        final hash = (x * 3.1 + y * 7.3).toInt();
        final rect = Rect.fromLTWH(x, y, winW, winH);
        if (hash % 4 == 0) {
          darkPath.addRect(rect);
        } else if (hash % 3 == 0) {
          cyanPath.addRect(rect);
        } else {
          warmPath.addRect(rect);
        }
      }
    }

    canvas.drawPath(darkPath, Paint()..color = const Color(0xFF1E272C));
    canvas.drawPath(cyanPath, Paint()..color = const Color(0xFF80DEEA));
    canvas.drawPath(warmPath, Paint()..color = const Color(0xFFFFD54F));
  }

  void _drawRooftopBillboard(
      Canvas canvas, double cx, double cy, bool isLeft) {
    const textOptions = ['GLIDE', 'FLY', 'PAPER CO', 'CATCH WIND'];
    final label = textOptions[_billboardIndex % textOptions.length];

    final bgPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;
    final framePaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 10), width: 34, height: 14),
        const Radius.circular(2),
      ),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 10), width: 34, height: 14),
        const Radius.circular(2),
      ),
      framePaint,
    );

    // Mini neon text painter
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 6.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFD54F),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - 10 - tp.height / 2));
  }

  void _drawHvacFan(Canvas canvas, double cx, double cy) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..style = PaintingStyle.fill;
    final fanPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final cagePaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 4), width: 22, height: 12),
        const Radius.circular(2),
      ),
      bodyPaint,
    );

    canvas.drawCircle(Offset(cx, cy + 4), 4.5, cagePaint);

    final angle = animTime * 16.0;
    canvas.save();
    canvas.translate(cx, cy + 4);
    canvas.rotate(angle);
    canvas.drawLine(const Offset(-4, 0), const Offset(4, 0), fanPaint);
    canvas.drawLine(const Offset(0, -4), const Offset(0, 4), fanPaint);
    canvas.restore();
  }

  void _drawWaterTower(Canvas canvas, double cx, double cy) {
    final woodPaint = Paint()..color = const Color(0xFF8D6E63)..style = PaintingStyle.fill;
    final legPaint = Paint()..color = const Color(0xFF455A64)..strokeWidth = 1.6..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx - 8, cy + 12), Offset(cx - 6, cy + 3), legPaint);
    canvas.drawLine(Offset(cx + 8, cy + 12), Offset(cx + 6, cy + 3), legPaint);

    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy - 2), width: 18, height: 12), woodPaint);
    final roofPath = Path()..moveTo(cx - 10, cy - 8)..lineTo(cx, cy - 16)..lineTo(cx + 10, cy - 8)..close();
    canvas.drawPath(roofPath, Paint()..color = const Color(0xFF5D4037)..style = PaintingStyle.fill);
  }

  void _drawAntennaSpire(Canvas canvas, double cx, double cy) {
    final mastPaint = Paint()..color = const Color(0xFFB0BEC5)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - 18), mastPaint);
    canvas.drawLine(Offset(cx - 4, cy - 8), Offset(cx + 4, cy - 8), mastPaint);

    final pulse = (math.sin(animTime * 8.0) * 0.5 + 0.5);
    final beaconPaint = Paint()..color = Color.fromRGBO(255, 23, 68, 0.4 + pulse * 0.6)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy - 18), 3.0, beaconPaint);
  }
}

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
    isThicket = rngRange(0, 1) < 0.25; // 25% Thicket elite variant
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

    if (math.Random().nextDouble() < dt * 1.8) {
      final startX = _fromLeft
          ? MathUtils.randomRange(size.x * 0.4, size.x)
          : MathUtils.randomRange(0, size.x * 0.6);
      _fallingLeaves.add(_LeafParticle(
        x: startX,
        y: size.y * 0.5,
        vx: MathUtils.randomRange(-15, 15),
        vy: MathUtils.randomRange(30, 60),
        color: const Color(0xFF81C784),
        angle: MathUtils.randomRange(0, math.pi * 2),
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

    final woodPaint = Paint()..color = const Color(0xFF5D4037)..style = PaintingStyle.fill;
    final branchPath = Path();
    if (fromLeft) {
      branchPath.moveTo(0, bh * 0.35);
      branchPath.quadraticBezierTo(bw * 0.4, bh * 0.4, bw * 0.8, bh * 0.5);
      branchPath.lineTo(bw * 0.85, bh * 0.6);
      branchPath.quadraticBezierTo(bw * 0.4, bh * 0.65, 0, bh * 0.75);
    } else {
      final rightX = size.x;
      branchPath.moveTo(rightX, bh * 0.35);
      branchPath.quadraticBezierTo(rightX - bw * 0.4, bh * 0.4, rightX - bw * 0.8, bh * 0.5);
      branchPath.lineTo(rightX - bw * 0.85, bh * 0.6);
      branchPath.quadraticBezierTo(rightX - bw * 0.4, bh * 0.65, rightX, bh * 0.75);
    }
    branchPath.close();
    canvas.drawPath(branchPath, woodPaint);

    _drawFoliageClusters(canvas, bw, bh, fromLeft);

    // Environmental Storytelling: Hanging Wooden Rope Swing
    if (!isThicket && bw > 85) {
      _drawHangingSwing(canvas, fromLeft ? bw * 0.65 : size.x - bw * 0.65, bh * 0.55, sway);
    }

    canvas.restore();
  }

  void _drawFoliageClusters(Canvas canvas, double bw, double bh, bool fromLeft) {
    final darkGreen = Paint()..color = const Color(0xFF2E7D32)..style = PaintingStyle.fill;
    final midGreen = Paint()..color = const Color(0xFF43A047)..style = PaintingStyle.fill;
    final lightGreen = Paint()..color = const Color(0xFF81C784)..style = PaintingStyle.fill;

    final clusterCenters = fromLeft
        ? [Offset(bw * 0.35, bh * 0.35), Offset(bw * 0.65, bh * 0.3), Offset(bw * 0.85, bh * 0.55)]
        : [Offset(size.x - bw * 0.35, bh * 0.35), Offset(size.x - bw * 0.65, bh * 0.3), Offset(size.x - bw * 0.85, bh * 0.55)];

    for (int i = 0; i < clusterCenters.length; i++) {
      final c = clusterCenters[i];
      final r = 15.0 + (i % 2) * 5.0;
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 2.0, height: r * 1.5), darkGreen);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - 2), width: r * 1.7, height: r * 1.2), midGreen);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - 2, c.dy - 4), width: r * 1.2, height: r * 0.8), lightGreen);
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
    isGolden = rngRange(0, 1) < 0.18; // 18% Golden Bird elite
    isFlock = rngRange(0, 1) < 0.22;  // 22% V-formation flocking
    _isScared = false;
    _velocityX = 0;

    _setupHitboxes();
  }

  void _setupHitboxes() {
    removeAll(children.whereType<ShapeHitbox>().toList());
    // Refined polygon hitbox for avian diamond body
    add(PolygonHitbox([
      Vector2(size.x * 0.5, 0),
      Vector2(size.x * 0.9, size.y * 0.5),
      Vector2(size.x * 0.5, size.y),
      Vector2(size.x * 0.1, size.y * 0.5),
    ]));
  }

  @override
  void updateObstacle(double dt) {
    _patrolPhase += _patrolFreq * dt;
    _wingFlapPhase += dt * (isGolden ? 12.0 : 9.0);

    // Ghost Interaction: Scared away when Ghost plane is near!
    try {
      final session = gameRef.ref.read(gameSessionProvider);
      if (session.activePowerUps.contains(PowerUpType.ghost)) {
        final dist = (position - gameRef.plane.position).length;
        if (dist < 130) _isScared = true;
      }
    } catch (_) {}

    if (_isScared) {
      position.x += (_velocityX.isNegative ? -240.0 : 240.0) * dt;
      position.y -= 120.0 * dt;
      return;
    }

    final prevX = position.x;
    final targetX = _spawnX + _patrolAmplitude * dynamicMovementFactor * math.sin(_patrolPhase);
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
    final Color bodyColor;
    final Color wingColor;

    if (isGolden) {
      bodyColor = const Color(0xFFFFD700);
      wingColor = const Color(0xFFFFF176);
    } else if (_birdSpecies == 1) {
      bodyColor = const Color(0xFFFFA000);
      wingColor = const Color(0xFFFFB300);
    } else {
      bodyColor = const Color(0xFF607D8B);
      wingColor = const Color(0xFF78909C);
    }

    // Wings
    final wingY = flapAmount * 8.0;
    final leftWing = Path()..moveTo(-4, 0)..quadraticBezierTo(-10, wingY - 6, -18, wingY - 2)..lineTo(-15, wingY + 4)..lineTo(-3, 3)..close();
    final rightWing = Path()..moveTo(4, 0)..quadraticBezierTo(10, wingY - 6, 18, wingY - 2)..lineTo(15, wingY + 4)..lineTo(3, 3)..close();
    canvas.drawPath(leftWing, Paint()..color = wingColor..style = PaintingStyle.fill);
    canvas.drawPath(rightWing, Paint()..color = wingColor..style = PaintingStyle.fill);

    // Body
    canvas.drawOval(const Rect.fromLTWH(-5, -8, 10, 16), Paint()..color = bodyColor..style = PaintingStyle.fill);
    canvas.drawCircle(const Offset(0, -7), 4.2, Paint()..color = bodyColor..style = PaintingStyle.fill);

    // Beak
    final beak = Path()..moveTo(-2, -9)..lineTo(0, -14)..lineTo(2, -9)..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFFD54F)..style = PaintingStyle.fill);

    if (isGolden) {
      final spark = Paint()..color = Colors.white.withOpacity(0.8);
      canvas.drawCircle(const Offset(-6, -2), 1.2, spark);
      canvas.drawCircle(const Offset(6, -2), 1.2, spark);
    }

    canvas.restore();
  }
}

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
    isArmed = rngRange(0, 1) < 0.25;      // 25% Armed Drone elite
    isOrbiting = rngRange(0, 1) < 0.20;   // 20% Orbiting drone behavior
    _shieldClashActive = false;

    _setupHitboxes();
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
    try {
      final session = gameRef.ref.read(gameSessionProvider);
      if (session.shieldActive) {
        final dist = (position - gameRef.plane.position).length;
        _shieldClashActive = dist < 80.0;
      } else {
        _shieldClashActive = false;
      }
    } catch (_) {}

    if (isOrbiting) {
      position.x += math.cos(_orbitAngle) * 55.0 * dt;
      return;
    }

    if (_trackingTimer < _trackingDuration) {
      _trackingTimer += dt;
      var targetX = gameRef.plane.position.x;
      final rawDiff = targetX - position.x;
      _isLockedOn = rawDiff.abs() < 40.0;
      final diff = rawDiff * dynamicMovementFactor;
      _velocityX = MathUtils.lerp(_velocityX, diff * 1.8, 0.10);
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

    // Armed Drone: Red laser targeting beam
    if (isArmed) {
      final laser = Paint()..color = const Color(0xFFFF1744).withOpacity(0.85)..strokeWidth = 1.4;
      canvas.drawLine(const Offset(0, 5), const Offset(0, 160), laser);
    }

    // Drone Arms & Chassis
    final armPaint = Paint()..color = const Color(0xFF37474F)..strokeWidth = 3.2..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-14, -10), const Offset(14, 10), armPaint);
    canvas.drawLine(const Offset(-14, 10), const Offset(14, -10), armPaint);

    final bodyPaint = Paint()..color = isArmed ? const Color(0xFFB71C1C) : const Color(0xFF263238)..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -7, 18, 14), const Radius.circular(3)), bodyPaint);

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

    canvas.restore();
    renderTelegraph(canvas);
  }

  void _drawSpinningRotor(Canvas canvas, Offset pos) {
    canvas.drawCircle(pos, 3.2, Paint()..color = const Color(0xFF455A64)..style = PaintingStyle.fill);
    canvas.drawOval(Rect.fromCenter(center: pos, width: 16, height: 6), Paint()..color = const Color(0x66B0BEC5)..style = PaintingStyle.fill);
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

  @override
  Color get telegraphColor => const Color(0xFF00E676);

  @override
  void onActivate(double scrollSpeed) {
    _bladeRadius = rngRange(60, 78);
    size = Vector2(_bladeRadius * 2.2, _bladeRadius * 2.2 + 60);
    _bladeAngle = rngRange(0, math.pi * 2);
    _rotSpeed = rngRange(1.2, 1.9) * (rngBool() ? 1 : -1);

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 14, position: Vector2(size.x * 0.5 - 14, _bladeRadius - 14)));
    add(RectangleHitbox(size: Vector2(16, 60), position: Vector2(size.x * 0.5 - 8, _bladeRadius)));
  }

  @override
  void updateObstacle(double dt) {
    _bladeAngle += _rotSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = _bladeRadius;

    final mast = Path()..moveTo(cx - 7, cy)..lineTo(cx - 12, size.y)..lineTo(cx + 12, size.y)..lineTo(cx + 7, cy)..close();
    canvas.drawPath(mast, Paint()..color = const Color(0xFFECEFF1)..style = PaintingStyle.fill);

    for (int i = 0; i < 3; i++) {
      final angle = _bladeAngle + i * (math.pi * 2 / 3);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      final blade = Path()..moveTo(-3, 0)..quadraticBezierTo(-6, _bladeRadius * 0.6, -2, _bladeRadius)..lineTo(0, _bladeRadius + 3)..lineTo(2, _bladeRadius)..quadraticBezierTo(4, _bladeRadius * 0.6, 3, 0)..close();
      canvas.drawPath(blade, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.restore();
    }

    canvas.drawCircle(Offset(cx, cy), 8.0, Paint()..color = const Color(0xFFFAFAFA));
    renderTelegraph(canvas);
  }
}

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

    final envelopePath = Path()
      ..moveTo(cx - 14, cy + 24)
      ..cubicTo(cx - 36, cy + 10, cx - 36, cy - 26, cx, cy - 28)
      ..cubicTo(cx + 36, cy - 26, cx + 36, cy + 10, cx + 14, cy + 24)
      ..close();
    canvas.drawPath(envelopePath, Paint()..color = const Color(0xFFE53935));

    final gore = Path()
      ..moveTo(cx - 7, cy + 24)
      ..cubicTo(cx - 16, cy + 8, cx - 16, cy - 25, cx, cy - 28)
      ..cubicTo(cx + 16, cy - 25, cx + 16, cy + 8, cx + 7, cy + 24)
      ..close();
    canvas.drawPath(gore, Paint()..color = const Color(0xFFFFD54F));

    // Wicker basket
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, 82), width: 20, height: 14), const Radius.circular(2)), Paint()..color = const Color(0xFF8D6E63));
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

  @override
  Color get telegraphColor => const Color(0xFF7C4DFF);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(100, 55);
    _chargeTimer = rngRange(1.2, 2.5);
    _lightningAlpha = 0;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 24, position: Vector2(8, 4)));
    add(CircleHitbox(radius: 28, position: Vector2(size.x * 0.5 - 28, 0)));
    add(CircleHitbox(radius: 22, position: Vector2(size.x - 52, 6)));
  }

  @override
  void updateObstacle(double dt) {
    _chargeTimer -= dt;
    if (_chargeTimer <= 0) {
      _chargeTimer = MathUtils.randomRange(2.0, 3.8);
      _lightningAlpha = 1.0;
    }
    if (_lightningAlpha > 0) _lightningAlpha = (_lightningAlpha - dt * 4.0).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;
    canvas.drawCircle(Offset(cx - 26, cy + 4), 22, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(Offset(cx + 26, cy + 4), 20, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(Offset(cx, cy), 28, Paint()..color = const Color(0xFF37474F));

    if (_lightningAlpha > 0) {
      final bolt = Path()..moveTo(cx, cy + 10)..lineTo(cx - 5, cy + 28)..lineTo(cx + 6, cy + 34)..lineTo(cx, cy + 50);
      canvas.drawPath(bolt, Paint()..color = Color.fromRGBO(0, 229, 255, _lightningAlpha)..strokeWidth = 2.4..style = PaintingStyle.stroke);
    }
    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. KiteObstacle — Exact Polygon Diamond Hitbox, Flowing Tail
// ─────────────────────────────────────────────────────────────────────────────

class KiteObstacle extends ObstacleComponent {
  KiteObstacle() : super(type: ObstacleType.kite);

  double _flutterPhase = 0;
  double _spawnX = 0;
  double _driftAmp = 50;

  @override
  Color get telegraphColor => const Color(0xFFFF4081);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(40, 110);
    _spawnX = position.x;
    _driftAmp = script?.driftAmp ?? rngRange(35, 65);
    _flutterPhase = rngRange(0, math.pi * 2);

    removeAll(children.whereType<ShapeHitbox>().toList());
    // Refined exact 4-point diamond PolygonHitbox
    add(PolygonHitbox([
      Vector2(size.x * 0.5, 2),
      Vector2(size.x * 0.5 + 14, 20),
      Vector2(size.x * 0.5, 38),
      Vector2(size.x * 0.5 - 14, 20),
    ]));
  }

  @override
  void updateObstacle(double dt) {
    _flutterPhase += dt * 3.5;
    position.x = (_spawnX + math.sin(_flutterPhase) * _driftAmp * dynamicMovementFactor).clamp(
      GameConfig.horizontalEdgeMargin + 20,
      GameConfig.designWidth - GameConfig.horizontalEdgeMargin - 20,
    );
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    const kiteY = 20.0;
    final tilt = math.sin(_flutterPhase) * 0.25;

    canvas.save();
    canvas.translate(cx, kiteY);
    canvas.rotate(tilt);

    final topF = Path()..moveTo(0, -18)..lineTo(-14, 0)..lineTo(0, 0)..close();
    canvas.drawPath(topF, Paint()..color = const Color(0xFFFF5252));
    final rightF = Path()..moveTo(0, -18)..lineTo(14, 0)..lineTo(0, 0)..close();
    canvas.drawPath(rightF, Paint()..color = const Color(0xFF00E5FF));
    final botLeftF = Path()..moveTo(-14, 0)..lineTo(0, 18)..lineTo(0, 0)..close();
    canvas.drawPath(botLeftF, Paint()..color = const Color(0xFFFFEB3B));
    final botRightF = Path()..moveTo(14, 0)..lineTo(0, 18)..lineTo(0, 0)..close();
    canvas.drawPath(botRightF, Paint()..color = const Color(0xFF7C4DFF));

    canvas.restore();
    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. TrafficPlaneObstacle (NEW) — Oncoming Rogue Paper Airplanes
// ─────────────────────────────────────────────────────────────────────────────

class TrafficPlaneObstacle extends ObstacleComponent {
  TrafficPlaneObstacle() : super(type: ObstacleType.trafficPlane);

  double _lateralSpeed = 0;

  @override
  Color get telegraphColor => const Color(0xFFFF9100);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(34, 34);
    _lateralSpeed = rngRange(-45, 45);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(PolygonHitbox([
      Vector2(size.x * 0.5, size.y),
      Vector2(size.x, 4),
      Vector2(size.x * 0.5, 12),
      Vector2(0, 4),
    ]));
  }

  @override
  void updateObstacle(double dt) {
    // High-speed oncoming traffic (descends faster toward the player)
    position.y += 65.0 * dt;
    position.x += _lateralSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;

    // Upward-facing oncoming paper dart
    final dart = Path()
      ..moveTo(cx, cy + 14)
      ..lineTo(cx + 14, cy - 12)
      ..lineTo(cx, cy - 6)
      ..lineTo(cx - 14, cy - 12)
      ..close();
    canvas.drawPath(dart, Paint()..color = const Color(0xFFFF7043));

    // Wingtip smoke contrails
    final contrail = Paint()..color = const Color(0x66FFFFFF)..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx - 14, cy - 12), Offset(cx - 14, cy - 26), contrail);
    canvas.drawLine(Offset(cx + 14, cy - 12), Offset(cx + 14, cy - 26), contrail);

    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. FireworksObstacle (NEW) — Ascending Firework Rocket & Popping Starbursts
// ─────────────────────────────────────────────────────────────────────────────

class FireworksObstacle extends ObstacleComponent {
  FireworksObstacle() : super(type: ObstacleType.fireworks);

  double _burstTimer = 0.8;
  bool _burst = false;

  @override
  Color get telegraphColor => const Color(0xFFFF4081);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(56, 56);
    _burstTimer = rngRange(0.6, 1.2);
    _burst = false;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 22, position: Vector2(6, 6)));
  }

  @override
  void updateObstacle(double dt) {
    if (!_burst) {
      _burstTimer -= dt;
      if (_burstTimer <= 0) _burst = true;
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;

    if (!_burst) {
      // Ascending rocket with sparks
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 14), Paint()..color = const Color(0xFFFF1744));
      canvas.drawCircle(Offset(cx, cy + 10), 3, Paint()..color = const Color(0xFFFFD54F));
    } else {
      // Popping multi-point starburst
      final burstPaint = Paint()..color = const Color(0xFFFF4081)..strokeWidth = 2.0;
      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(Offset(cx, cy), Offset(cx + math.cos(a) * 22, cy + math.sin(a) * 22), burstPaint);
      }
      canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = const Color(0xFFFFF9C4));
    }

    renderTelegraph(canvas);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 12. WeatherBalloonObstacle (NEW) — Satellite Cluster & Weather Balloon
// ─────────────────────────────────────────────────────────────────────────────

class WeatherBalloonObstacle extends ObstacleComponent {
  WeatherBalloonObstacle() : super(type: ObstacleType.weatherBalloon);

  @override
  Color get telegraphColor => const Color(0xFF00E5FF);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(64, 72);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 24, position: Vector2(8, 0)));
    add(RectangleHitbox(size: Vector2(28, 20), position: Vector2(18, 48)));
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    // Weather balloon dome
    canvas.drawCircle(Offset(cx, 24), 24, Paint()..color = const Color(0xFFE0F7FA));
    canvas.drawCircle(Offset(cx, 24), 24, Paint()..color = const Color(0xFF80DEEA)..style = PaintingStyle.stroke..strokeWidth = 1.4);

    // Tether cables & satellite sensor box
    canvas.drawLine(Offset(cx - 10, 48), Offset(cx - 8, 54), Paint()..color = const Color(0xFF78909C));
    canvas.drawLine(Offset(cx + 10, 48), Offset(cx + 8, 54), Paint()..color = const Color(0xFF78909C));
    canvas.drawRect(Rect.fromLTWH(cx - 14, 54, 28, 16), Paint()..color = const Color(0xFF455A64));
    canvas.drawCircle(Offset(cx, 62), 3, Paint()..color = const Color(0xFF00E5FF));

    renderTelegraph(canvas);
  }
}

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

    final line = Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 1.8;
    canvas.drawLine(Offset(0, 10), Offset(_gapX, 12), line);
    canvas.drawLine(Offset(rStart, 12), Offset(w, 10), line);

    // Paper dolls hanging with clothespins
    _drawPaperDolls(canvas, 0, _gapX);
    _drawPaperDolls(canvas, rStart, w);

    renderTelegraph(canvas);
  }

  void _drawPaperDolls(Canvas canvas, double startX, double endX) {
    final dollPaint = Paint()..color = const Color(0xFFFFD54F)..style = PaintingStyle.fill;
    final pinPaint = Paint()..color = const Color(0xFF5D4037)..style = PaintingStyle.fill;

    for (double x = startX + 15; x < endX - 15; x += 28) {
      canvas.drawRect(Rect.fromLTWH(x - 2, 8, 4, 4), pinPaint);
      final doll = Path()..moveTo(x, 12)..lineTo(x + 8, 22)..lineTo(x + 5, 34)..lineTo(x - 5, 34)..lineTo(x - 8, 22)..close();
      canvas.drawPath(doll, dollPaint);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 14. WindSockObstacle (NEW) — Dynamic Wind-Direction Aviation Windsock
// ─────────────────────────────────────────────────────────────────────────────

class WindSockObstacle extends ObstacleComponent {
  WindSockObstacle() : super(type: ObstacleType.windsock);

  @override
  Color get telegraphColor => const Color(0xFFFF6D00);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(48, 54);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: Vector2(36, 40), position: Vector2(6, 6)));
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x * 0.5;
    // Mast
    canvas.drawLine(Offset(cx, 0), Offset(cx, 54), Paint()..color = const Color(0xFF90A4AE)..strokeWidth = 2.4);

    // Striped windsock cone pointing in wind direction
    final sock = Path()
      ..moveTo(cx, 8)
      ..lineTo(cx + 24, 14)
      ..lineTo(cx + 22, 28)
      ..lineTo(cx, 24)
      ..close();
    canvas.drawPath(sock, Paint()..color = const Color(0xFFFF5722));

    // White stripes
    canvas.drawRect(Rect.fromLTWH(cx + 6, 9.5, 6, 15), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(cx + 15, 12, 5, 13), Paint()..color = Colors.white);

    renderTelegraph(canvas);
  }
}
