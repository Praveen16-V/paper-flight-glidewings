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
import '../effects/coin_feedback.dart';
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

  /// Non-null while this obstacle belongs to a curated two-part encounter.
  /// The spawner uses it to reserve the screen until the full pattern clears.
  String? combinationId;
  bool get isCombinationMember => combinationId != null;

  late math.Random _rng;

  double rngRange(double min, double max) =>
      min + _rng.nextDouble() * (max - min);

  int rngInt(int min, int max) => min + _rng.nextInt(max - min + 1);

  bool rngBool() => _rng.nextBool();

  double animTime = 0.0;
  bool challengeGapCounted = false;

  bool get hasTelegraph => true;
  Color get telegraphColor => const Color(0xFFFF9800);

  /// Distance above the viewport at which an early-warning obstacle begins its
  /// telegraph. Bosses can override this to keep their full silhouette hidden
  /// while they announce the encounter.
  double get earlyWarningLeadDistance => 260.0;

  /// Pooled obstacles normally rebuild hitboxes on activation. Long segmented
  /// obstacles can retain their child hitboxes between pool uses and only move
  /// them, avoiding a burst of component allocations at every boss spawn.
  bool get retainsHitboxesWhenInactive => false;

  // ── Activation ─────────────────────────────────────────────────────────────

  void activate({
    required double spawnX,
    required double scrollSpeed,
    double? safeCorridorX,
    void Function(ObstacleComponent)? recycleCallback,
    ObstacleScript? script,
    String? combinationId,
    math.Random? rng,
  }) {
    final earlyWarning = type == ObstacleType.drone ||
        type == ObstacleType.bird ||
        type == ObstacleType.stormCloud ||
        type == ObstacleType.trafficPlane ||
        type == ObstacleType.fireworks ||
        type == ObstacleType.lightningStrike ||
        type == ObstacleType.meteorShower ||
        type == ObstacleType.tornado ||
        type == ObstacleType.flockMigration ||
        type == ObstacleType.whaleBreach ||
        type == ObstacleType.paperDragon;
    position = Vector2(
      spawnX,
      earlyWarning ? -earlyWarningLeadDistance : GameConfig.obstacleSpawnY,
    );
    _active = true;
    _nearMissAwarded = false;
    _minNearMissClearance = double.infinity;
    animTime = 0.0;
    challengeGapCounted = false;
    onRecycle = recycleCallback;
    this.safeCorridorX = safeCorridorX;
    this.script = script;
    this.combinationId = combinationId;
    _rng = rng ?? math.Random();
    onActivate(scrollSpeed);
    _playThreatCue();
  }

  void deactivate() {
    _active = false;
    onRecycle = null;
    safeCorridorX = null;
    script = null;
    combinationId = null;
    _nearMissAwarded = false;
    _minNearMissClearance = double.infinity;
    if (!retainsHitboxesWhenInactive) {
      removeAll(children.whereType<ShapeHitbox>().toList());
    }
  }

  /// Shield Lv2 can reflect projectile-class hazards. Recycling through the
  /// original callback preserves object-pool ownership and avoids a duplicate
  /// collision on the next frame.
  void deflectByShield() => recycleAfterInteraction();

  /// Resolves a player-driven obstacle interaction (a shield reflection, a
  /// severed tether, or a future gadget response) through the same pool-safe
  /// recycle path. Subclasses should award their feedback before calling this.
  void recycleAfterInteraction() {
    if (!_active) return;
    _active = false;
    onRecycle?.call(this);
  }

  void onActivate(double scrollSpeed) {}

  /// Returns a squared distance when this obstacle is inside a live paper-snap
  /// interaction envelope, otherwise `null`. Keeping target selection on the
  /// obstacle lets every future interactive family define its own fair shape.
  double? snapInteractionDistanceSquaredTo(Vector2 planePosition) => null;

  /// Handles the selected paper-snap interaction. A `true` result consumes the
  /// current snap pulse, so only one nearby target can resolve per burst.
  bool resolveSnapInteraction(Vector2 planePosition) => false;

  void _playThreatCue() {
    final cue = switch (type) {
      ObstacleType.drone => 'drone_warning.wav',
      ObstacleType.bird || ObstacleType.flockMigration => 'bird_warning.wav',
      ObstacleType.stormCloud ||
      ObstacleType.lightningStrike ||
      ObstacleType.paperDragon => 'thunder_warning.wav',
      ObstacleType.tornado => 'wind_loop.wav',
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

    if (type.isCursedMagnetAttractable &&
        game.hasCorruptedPowerUp(CorruptedPowerUpType.cursedMagnet)) {
      final plane = game.plane;
      final dx = plane.position.x - position.x;
      final dy = plane.position.y - position.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance > 1 && distance < GameConfig.cursedMagnetRadius) {
        position += Vector2(dx / distance, dy / distance) *
            (GameConfig.cursedMagnetObstaclePullSpeed * dt);
      }
    }

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
    if (!hasTelegraph ||
        !_active ||
        position.y >= 0 ||
        position.y < -earlyWarningLeadDistance) {
      return;
    }

    final progress =
        (1.0 - (position.y.abs() / earlyWarningLeadDistance)).clamp(0.0, 1.0).toDouble();
    final pulse = (math.sin(animTime * 14.0) * 0.5 + 0.5);
    final alpha =
        (progress * (0.65 + 0.35 * pulse)).clamp(0.0, 1.0).toDouble();

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

    _drawArrivalDial(canvas, progress, alpha);
    canvas.drawCircle(Offset.zero, 14, glowPaint);

    // Linked beacons distinguish a planned pair from a lone hazard while it
    // is still off-screen. The actual corridor remains intentionally clean.
    if (isCombinationMember) {
      final linkPaint = Paint()
        ..color = const Color(0xFFB2EBF2).withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(const Offset(-4.2, -16.5), 3.4, linkPaint);
      canvas.drawCircle(const Offset(4.2, -16.5), 3.4, linkPaint);
      canvas.drawLine(
        const Offset(-0.8, -16.5),
        const Offset(0.8, -16.5),
        linkPaint,
      );
    }

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

  /// A three-tick countdown ring makes the time-to-arrival legible even when
  /// the player is concentrating on the plane rather than reading a label.
  void _drawArrivalDial(Canvas canvas, double progress, double alpha) {
    final radius = GameConfig.telegraphCountdownRadius;
    final track = Paint()
      ..color = telegraphColor.withOpacity(alpha * .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = telegraphColor.withOpacity(alpha * .95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, fill);

    final tickPaint = Paint()
      ..color = telegraphColor.withOpacity(alpha * .78)
      ..strokeWidth = 1.0;
    for (var i = 0; i < GameConfig.telegraphCountdownTickCount; i++) {
      final angle = -math.pi / 2 +
          i * math.pi * 2 / GameConfig.telegraphCountdownTickCount;
      final inner = radius - 2.8;
      final outer = radius + 1.6;
      canvas.drawLine(
        Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        tickPaint,
      );
    }
  }

  /// Draws the profile-specific intent projection beneath the shared warning
  /// badge. Gate and boss profiles supply their own richer previews.
  void renderThreatPreview(
    Canvas canvas,
    double x,
    double y,
    double progress,
    double pulse,
  ) {
    final startY = y + GameConfig.telegraphProjectionStartOffset;
    final depth = GameConfig.telegraphProjectionDepth * (.48 + progress * .52);
    final alpha = (progress * .68).clamp(0.0, 1.0).toDouble();

    switch (type.telegraphStyle) {
      case ObstacleTelegraphStyle.pinpoint:
        _drawPinpointPreview(canvas, x, startY + depth * .58, alpha, pulse);
        break;
      case ObstacleTelegraphStyle.trajectory:
        _drawTrajectoryPreview(canvas, x, startY, depth, alpha);
        break;
      case ObstacleTelegraphStyle.lane:
        _drawLanePreview(canvas, x, startY, depth, alpha);
        break;
      case ObstacleTelegraphStyle.area:
        _drawAreaPreview(canvas, x, startY, depth, alpha, pulse);
        break;
      case ObstacleTelegraphStyle.formation:
        _drawFormationPreview(canvas, x, startY, depth, alpha);
        break;
      case ObstacleTelegraphStyle.gate:
      case ObstacleTelegraphStyle.boss:
        break;
    }
  }

  void _drawPinpointPreview(
    Canvas canvas,
    double x,
    double y,
    double alpha,
    double pulse,
  ) {
    final paint = Paint()
      ..color = telegraphColor.withOpacity(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final radius = 8.0 + pulse * 3.0;
    canvas.drawCircle(Offset(x, y), radius, paint);
    canvas.drawLine(Offset(x - radius - 4, y), Offset(x + radius + 4, y), paint);
    canvas.drawLine(Offset(x, y - radius - 4), Offset(x, y + radius + 4), paint);
  }

  void _drawTrajectoryPreview(
    Canvas canvas,
    double x,
    double startY,
    double depth,
    double alpha,
  ) {
    final pathPaint = Paint()
      ..color = telegraphColor.withOpacity(alpha * .44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, startY), Offset(x, startY + depth), pathPaint);

    final arrowPaint = Paint()
      ..color = telegraphColor.withOpacity(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < GameConfig.telegraphTrajectoryChevronCount; i++) {
      final t = (i + 1) / (GameConfig.telegraphTrajectoryChevronCount + 1);
      final cy = startY + depth * t;
      final sway = math.sin(animTime * 5.0 + i * 1.7) * 3.5;
      canvas.drawLine(Offset(x - 5 + sway, cy - 3), Offset(x + sway, cy + 3), arrowPaint);
      canvas.drawLine(Offset(x + sway, cy + 3), Offset(x + 5 + sway, cy - 3), arrowPaint);
    }
  }

  void _drawLanePreview(
    Canvas canvas,
    double x,
    double startY,
    double depth,
    double alpha,
  ) {
    final width = math.max(14.0, size.x * .28).toDouble();
    final band = Rect.fromCenter(
      center: Offset(x, startY + depth * .5),
      width: width,
      height: depth,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(5)),
      Paint()..color = telegraphColor.withOpacity(alpha * .16),
    );
    final edge = Paint()
      ..color = telegraphColor.withOpacity(alpha * .86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas.drawLine(Offset(band.left, band.top), Offset(band.left, band.bottom), edge);
    canvas.drawLine(Offset(band.right, band.top), Offset(band.right, band.bottom), edge);
  }

  void _drawAreaPreview(
    Canvas canvas,
    double x,
    double startY,
    double depth,
    double alpha,
    double pulse,
  ) {
    final paint = Paint()
      ..color = telegraphColor.withOpacity(alpha * .82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(x, startY + depth * .48);
    for (var i = 0; i < 3; i++) {
      final radius = 10.0 + i * 13.0 + pulse * 3.0;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * .82,
        math.pi * 1.64,
        false,
        paint,
      );
    }
  }

  void _drawFormationPreview(
    Canvas canvas,
    double x,
    double startY,
    double depth,
    double alpha,
  ) {
    final paint = Paint()
      ..color = telegraphColor.withOpacity(alpha)
      ..style = PaintingStyle.fill;
    final baseY = startY + depth * .56;
    for (var i = 0; i < 5; i++) {
      final rank = (i + 1) ~/ 2;
      final side = i.isEven ? -1.0 : 1.0;
      final px = x + side * rank * 12.0;
      final py = baseY + rank * 8.0;
      canvas.drawCircle(Offset(px, py), i == 0 ? 3.8 : 2.6, paint);
    }
  }

  /// Shared preview for a gap obstacle. Each gate supplies its real generated
  /// opening, so the player sees the route they can actually take—not a generic
  /// centre-screen suggestion.
  void renderSafeCorridorPreview(
    Canvas canvas, {
    required double localY,
    required double gapLeft,
    required double gapWidth,
    required double progress,
    required double pulse,
  }) {
    final alpha = (progress * .82).clamp(0.0, 1.0).toDouble();
    final height = GameConfig.telegraphGatePreviewHeight;
    final rect = Rect.fromLTWH(gapLeft, localY - height * .5, gapWidth, height);
    final fill = Paint()
      ..color = const Color(0xFF80DEEA).withOpacity(alpha * .20)
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = const Color(0xFFB2EBF2).withOpacity(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      fill,
    );
    canvas.drawLine(Offset(rect.left, rect.top - 5), Offset(rect.left, rect.bottom + 5), edge);
    canvas.drawLine(Offset(rect.right, rect.top - 5), Offset(rect.right, rect.bottom + 5), edge);

    final centerX = rect.center.dx;
    final arrowY = rect.center.dy + pulse * 2.0;
    canvas.drawLine(Offset(centerX - 6, arrowY - 3), Offset(centerX, arrowY + 3), edge);
    canvas.drawLine(Offset(centerX, arrowY + 3), Offset(centerX + 6, arrowY - 3), edge);
  }
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
// 9. KiteObstacle — Snap-Interactive Tether, Diamond Hitbox & Flowing Tail
// ─────────────────────────────────────────────────────────────────────────────

class KiteObstacle extends ObstacleComponent {
  KiteObstacle() : super(type: ObstacleType.kite);

  double _flutterPhase = 0;
  double _spawnX = 0;
  double _driftAmp = 50;
  double _snapHintStrength = 0;

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
  void updateObstacle(double dt) {
    _flutterPhase += dt * 3.5;
    position.x = (_spawnX +
            math.sin(_flutterPhase) * _driftAmp * dynamicMovementFactor)
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

    canvas.save();
    canvas.translate(cx, kiteY);
    canvas.rotate(tilt);

    final topF = Path()
      ..moveTo(0, -18)
      ..lineTo(-14, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(topF, Paint()..color = const Color(0xFFFF5252));
    final rightF = Path()
      ..moveTo(0, -18)
      ..lineTo(14, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(rightF, Paint()..color = const Color(0xFF00E5FF));
    final botLeftF = Path()
      ..moveTo(-14, 0)
      ..lineTo(0, 18)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(botLeftF, Paint()..color = const Color(0xFFFFEB3B));
    final botRightF = Path()
      ..moveTo(14, 0)
      ..lineTo(0, 18)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(botRightF, Paint()..color = const Color(0xFF7C4DFF));

    canvas.restore();
    _drawSnapHint(canvas, cx, kiteY);
    renderTelegraph(canvas);
  }

  void _drawTetherTail(Canvas canvas, double cx, double kiteY) {
    final tailPaint = Paint()
      ..color = const Color(0xFF5D4037).withOpacity(.74)
      ..strokeWidth = 1.2
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

// ─────────────────────────────────────────────────────────────────────────────
// 15. LightningStrikeObstacle — Telegraph, Flash, Vertical Strike
// ─────────────────────────────────────────────────────────────────────────────

class LightningStrikeObstacle extends ObstacleComponent {
  LightningStrikeObstacle() : super(type: ObstacleType.lightningStrike);

  bool _struck = false;
  double _strikeTimer = 0;

  @override
  Color get telegraphColor => const Color(0xFFFFF176);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(44, GameConfig.designHeight);
    _struck = false;
    _strikeTimer = 0;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void updateObstacle(double dt) {
    if (!_struck && position.y >= -18) {
      _struck = true;
      _strikeTimer = .34;
      add(RectangleHitbox(
        size: Vector2(20, GameConfig.designHeight),
        position: Vector2(12, 0),
      ));
    }
    if (_struck) {
      _strikeTimer -= dt;
      if (_strikeTimer <= 0) {
        _active = false;
        onRecycle?.call(this);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final x = size.x * .5;
    if (!_struck) {
      final warn = Paint()
        ..color = const Color(0x44FFF176)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), warn);
      renderTelegraph(canvas);
      return;
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0x33FFFDE7),
    );
    final bolt = Path()..moveTo(x, 0);
    for (var i = 0; i < 12; i++) {
      final y = (i + 1) * size.y / 12;
      final dx = i.isEven ? -10.0 : 10.0;
      bolt.lineTo(x + dx, y - 18);
      bolt.lineTo(x, y);
    }
    final glow = Paint()
      ..color = const Color(0x99FFF176)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final core = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(bolt, glow);
    canvas.drawPath(bolt, core);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 16. MeteorShowerObstacle — Atmosphere Impacts with Warning Shadows
// ─────────────────────────────────────────────────────────────────────────────

class MeteorShowerObstacle extends ObstacleComponent {
  MeteorShowerObstacle() : super(type: ObstacleType.meteorShower);

  final List<_Meteor> _meteors = [];

  @override
  Color get telegraphColor => const Color(0xFFFFAB91);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(GameConfig.designWidth, 300);
    _meteors.clear();
    removeAll(children.whereType<ShapeHitbox>().toList());
    for (var i = 0; i < 4; i++) {
      final meteor = _Meteor(
        x: rngRange(42, GameConfig.designWidth - 42),
        y: 35 + i * 63 + rngRange(-12, 12),
        radius: rngRange(9, 16),
        phase: rngRange(0, math.pi * 2),
      );
      _meteors.add(meteor);
      add(CircleHitbox(
        radius: meteor.radius,
        position: Vector2(meteor.x - meteor.radius, meteor.y - meteor.radius),
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    for (final meteor in _meteors) {
      final shadow = Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(meteor.x + 10, meteor.y + 24),
          width: meteor.radius * 2.8,
          height: meteor.radius * .8,
        ),
        shadow,
      );
      final trail = Paint()
        ..color = const Color(0x99FF7043)
        ..strokeWidth = meteor.radius * .72
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(meteor.x - meteor.radius * 2.2, meteor.y - meteor.radius * 2.5),
        Offset(meteor.x, meteor.y),
        trail,
      );
      canvas.drawCircle(
        Offset(meteor.x, meteor.y),
        meteor.radius,
        Paint()..color = const Color(0xFF5D4037),
      );
      canvas.drawCircle(
        Offset(meteor.x - meteor.radius * .22, meteor.y - meteor.radius * .25),
        meteor.radius * .35,
        Paint()..color = const Color(0xFFFFAB91),
      );
    }
    renderTelegraph(canvas);
  }
}

class _Meteor {
  const _Meteor({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double phase;
}

// ─────────────────────────────────────────────────────────────────────────────
// 17. TornadoObstacle — Rotating Wind Column with Pull Force
// ─────────────────────────────────────────────────────────────────────────────

class TornadoObstacle extends ObstacleComponent {
  TornadoObstacle() : super(type: ObstacleType.tornado);

  static const double _pullRadius = 128;

  @override
  Color get telegraphColor => const Color(0xFFB3E5FC);

  @override
  void onActivate(double scrollSpeed) {
    size = Vector2(92, 190);
    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: 35, position: Vector2(11, 74)));
  }

  @override
  void updateObstacle(double dt) {
    final center = position + Vector2(0, size.y * .58);
    final plane = game.plane;
    final delta = center - plane.position;
    final distance = delta.length;
    if (distance > 1 && distance < _pullRadius) {
      final force = delta.normalized() *
          (GameConfig.maxWindForce * 2.0 * (1.0 - distance / _pullRadius) * dt);
      plane.applyTornadoPull(force);
    }
  }

  @override
  void render(Canvas canvas) {
    final centerX = size.x * .5;
    final swirl = Paint()
      ..color = const Color(0x88B3E5FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (var i = 0; i < 6; i++) {
      final y = 22 + i * 25.0;
      final width = 28 + i * 8.0;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(centerX + math.sin(animTime * 8 + i) * 7, y),
          width: width,
          height: 14,
        ),
        animTime * 5 + i * .65,
        math.pi * 1.5,
        false,
        swirl,
      );
    }
    final core = Paint()
      ..color = const Color(0x2264B5F6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX, 104), width: 58, height: 142), core);
    renderTelegraph(canvas);
  }
}

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
    final birdPaint = Paint()..style = PaintingStyle.fill;
    for (final bird in _birds) {
      final pos = _birdPosition(bird);
      final flap = math.sin(animTime * 12 + bird.phase) * bird.size * .55;
      birdPaint.color = const Color(0xFF37474F);
      final shape = Path()
        ..moveTo(pos.x, pos.y)
        ..quadraticBezierTo(pos.x - bird.size, pos.y - flap, pos.x - bird.size * 1.8, pos.y)
        ..quadraticBezierTo(pos.x - bird.size, pos.y + flap * .4, pos.x, pos.y)
        ..quadraticBezierTo(pos.x + bird.size, pos.y - flap, pos.x + bird.size * 1.8, pos.y)
        ..quadraticBezierTo(pos.x + bird.size, pos.y + flap * .4, pos.x, pos.y)
        ..close();
      canvas.drawPath(shape, birdPaint);
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
    position.x = GameConfig.designWidth * .5;
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
    canvas.drawPath(body, Paint()..color = const Color(0xFF1565C0));
    canvas.drawPath(belly, Paint()..color = const Color(0xFFB3E5FC));

    // Dorsal fin and tail read clearly as a giant living silhouette.
    final fin = Path()
      ..moveTo(104, 72)
      ..lineTo(124, 24)
      ..lineTo(144, 78)
      ..close();
    canvas.drawPath(fin, Paint()..color = const Color(0xFF0D47A1));
    final tail = Path()
      ..moveTo(28, 112)
      ..quadraticBezierTo(2, 85, 0, 112)
      ..quadraticBezierTo(10, 137, 30, 122)
      ..quadraticBezierTo(6, 151, 2, 170)
      ..quadraticBezierTo(34, 154, 42, 125)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFF0D47A1));

    canvas.drawCircle(const Offset(220, 78), 3.2, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(221, 78), 1.3, Paint()..color = const Color(0xFF102027));

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
    _bodyPaint.color = segment.index.isEven
        ? const Color(0xFFA5274F)
        : const Color(0xFFB92B56);

    canvas.save();
    canvas.translate(segment.center.x, segment.center.y);
    canvas.rotate(segment.heading);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.35,
        height: radius * 1.58,
      ),
      _bodyPaint,
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
