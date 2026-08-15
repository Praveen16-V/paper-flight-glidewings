import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
import '../../events/gameplay_event_bus.dart';
import '../../paper_flight_game.dart';
import '../effects/coin_feedback.dart';
import '../plane_component.dart';
import 'obstacle_script.dart';

// The twenty concrete obstacle families live in focused part files below;
// they share this library's imports and namespace.
part 'obstacle_gates_part.dart';
part 'obstacle_nature_part.dart';
part 'obstacle_machines_part.dart';
part 'obstacle_floaters_part.dart';
part 'obstacle_traffic_part.dart';
part 'obstacle_backyard_part.dart';
part 'obstacle_storm_part.dart';
part 'obstacle_giants_part.dart';
part 'obstacle_dragon_part.dart';

/// Base class for all obstacle types.
abstract class ObstacleComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  ObstacleComponent({required this.type}) : super(anchor: Anchor.topCenter);

  final ObstacleType type;

  bool _active = false;
  bool get isActive => _active;
  bool _nearMissAwarded = false;

  int _durability = 0;
  bool get isDestructible => type.isDestructible;
  bool get acceptsSnapInteraction => type.isSnapInteractive || isDestructible;
  int get durability => _durability;
  int get maxDurability => type.destructibleHitPoints;
  double get durabilityFraction => maxDurability <= 0
      ? 0.0
      : (_durability / maxDurability).clamp(0.0, 1.0).toDouble();

  double _minNearMissClearance = double.infinity;
  void Function(ObstacleComponent)? onRecycle;

  /// Snapshot of this obstacle's collision shapes, rebuilt on activation and
  /// whenever a subclass mutates its hitboxes (lightning strikes, flock
  /// movement). The per-frame near-miss clearance scan iterates this list
  /// instead of walking the component tree.
  List<ShapeHitbox> _cachedHitboxes = const [];

  /// Subclasses call this after adding/removing hitboxes so the near-miss
  /// clearance scan always sees the current collision silhouette.
  void refreshHitboxCache() {
    _cachedHitboxes = children.whereType<ShapeHitbox>().toList(growable: false);
  }

  double? safeCorridorX;
  ObstacleScript? script;

  /// Non-null while this obstacle belongs to a curated two-part encounter.
  /// The spawner uses it to reserve the screen until the full pattern clears.
  String? combinationId;
  bool get isCombinationMember => combinationId != null;

  ObstacleSynergy? _activeSynergy;
  ObstacleSynergy? get activeSynergy => _activeSynergy;
  bool get hasActiveSynergy => _activeSynergy != null;

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
    _durability = type.destructibleHitPoints;
    _minNearMissClearance = double.infinity;
    animTime = 0.0;
    challengeGapCounted = false;
    onRecycle = recycleCallback;
    this.safeCorridorX = safeCorridorX;
    this.script = script;
    this.combinationId = combinationId;
    setObstacleSynergy(null);
    _rng = rng ?? math.Random();
    onActivate(scrollSpeed);
    refreshHitboxCache();
    _playThreatCue();
  }

  void deactivate() {
    _active = false;
    onRecycle = null;
    safeCorridorX = null;
    script = null;
    combinationId = null;
    setObstacleSynergy(null);
    _nearMissAwarded = false;
    _durability = 0;
    _minNearMissClearance = double.infinity;
    if (!retainsHitboxesWhenInactive) {
      removeAll(children.whereType<ShapeHitbox>().toList());
    }
    _cachedHitboxes = const [];
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

  /// Called by the synergy coordinator only when the linked state actually
  /// changes, keeping per-frame pair detection allocation-free for obstacles.
  void setObstacleSynergy(ObstacleSynergy? synergy) {
    if (_activeSynergy == synergy) return;
    _activeSynergy = synergy;
    onObstacleSynergyChanged(synergy);
  }

  void onObstacleSynergyChanged(ObstacleSynergy? synergy) {}

  /// Returns a squared distance when this obstacle is inside a live paper-snap
  /// interaction envelope, otherwise `null`. Subclasses can replace the
  /// envelope for bespoke interactions (such as kite tethers); destructibles
  /// use this common, forward-facing target volume.
  double? snapInteractionDistanceSquaredTo(Vector2 planePosition) {
    if (!isActive || !isDestructible) return null;
    final dx = position.x - planePosition.x;
    final dy = position.y + size.y * .5 - planePosition.y;
    if (dx.abs() > GameConfig.destructibleSnapHorizontalReach ||
        dy < -GameConfig.destructibleSnapReachAhead ||
        dy > GameConfig.destructibleSnapReachBehind) {
      return null;
    }
    return dx * dx + dy * dy;
  }

  /// Handles the selected paper-snap interaction. A `true` result consumes the
  /// current snap pulse, so only one nearby target can resolve per burst.
  bool resolveSnapInteraction(Vector2 planePosition) {
    if (snapInteractionDistanceSquaredTo(planePosition) == null) return false;
    return _applySnapDamage();
  }

  bool _applySnapDamage() {
    if (!isDestructible || !_active) return false;
    if (_durability <= 0) _durability = maxDurability;
    _durability--;

    final impactPosition = Vector2(position.x, position.y + size.y * .5);
    if (_durability > 0) {
      game.world.add(
        ColoredBurst(
          position: impactPosition.clone(),
          color: const Color(0xFFFFAB40),
        ),
      );
      game.world.add(
        FloatingScoreText(
          position: impactPosition.clone(),
          text: 'CRACK! $_durability LEFT',
          color: const Color(0xFFFFAB40),
          fontSize: 14,
        ),
      );
      game.gameFeelSystem.onNearMiss();
      return true;
    }

    final comboNotches = GameConfig.destructibleDestroyComboNotches.toInt();
    game.scoringSystem
        .awardComboNotches(GameConfig.destructibleDestroyComboNotches);
    game.inputManager.restoreSnapCharge(GameConfig.destructibleSnapChargeRefund);
    game.collectibleSpawner.spawnCoinLine(
      x: impactPosition.x,
      startY: impactPosition.y,
      count: GameConfig.destructibleDestroyCoinCount,
      spacing: GameConfig.destructibleDestroyCoinSpacing,
    );
    game.world.add(
      ColoredBurst(
        position: impactPosition.clone(),
        color: const Color(0xFFFFD740),
      ),
    );
    game.world.add(
      FloatingScoreText(
        position: impactPosition.clone(),
        text: 'PAPER BREAK! +$comboNotches COMBO',
        color: const Color(0xFFFFD740),
        fontSize: 16,
      ),
    );
    game.gameFeelSystem.onCoinCollected(game.scoringSystem.comboCount);
    game.gameplayEvents.emit(ObstacleDestroyedGameplayEvent(type));
    recycleAfterInteraction();
    return true;
  }

  /// Draws an intentionally tiny integrity strip, preserving the obstacle's
  /// silhouette while making a second drone snap or a fragile target readable.
  void renderDestructibleIntegrity(
    Canvas canvas, {
    required double centerX,
    required double topY,
  }) {
    if (!isDestructible || maxDurability <= 0) return;

    const width = 26.0;
    const height = 3.4;
    final rect = Rect.fromLTWH(centerX - width * .5, topY, width, height);
    final background = Paint()
      ..color = const Color(0x99000000)
      ..style = PaintingStyle.fill;
    final fraction = durabilityFraction;
    final fill = Paint()
      ..color = Color.lerp(
        const Color(0xFFFF5252),
        const Color(0xFF80DEEA),
        fraction,
      )!
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      background,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, rect.width * fraction, rect.height),
        const Radius.circular(2),
      ),
      fill,
    );

    if (fraction < 1.0) {
      final crack = Paint()
        ..color = const Color(0xFFFFF3E0).withOpacity(.78)
        ..strokeWidth = .8;
      canvas.drawLine(
        Offset(centerX - 5, topY + height + 2),
        Offset(centerX - 1, topY + height + 6),
        crack,
      );
      canvas.drawLine(
        Offset(centerX - 1, topY + height + 6),
        Offset(centerX + 3, topY + height + 3),
        crack,
      );
    }
  }

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
    // Same rate-aware playback path as the near-miss sting: an AudioPlayer with
    // an explicit playback rate, disposed once the cue finishes.
    final player = AudioPlayer();
    try {
      await player.setPlaybackRate(rate);
      await player.play(AssetSource('audio/$cue'), volume: 0.32);
      player.onPlayerComplete.listen((_) async {
        await player.dispose();
      });
    } catch (_) {
      try {
        await player.dispose();
      } catch (_) {}
      // Audio playback safely ignored if the asset is unsupported on this device.
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_active) return;

    animTime += dt;
    position.y += game.scrollSpeed * dt;

    final powerUps = game.powerUpState;
    if (type.isCursedMagnetAttractable && powerUps.cursedMagnetActive) {
      final plane = game.plane;
      final dx = plane.position.x - position.x;
      final dy = plane.position.y - position.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance > 1 && distance < GameConfig.cursedMagnetRadius) {
        position += Vector2(dx / distance, dy / distance) *
            (GameConfig.cursedMagnetObstaclePullSpeed * dt);
      }
    }

    // Black Hole vacuum: small hazards are dragged into the vortex and
    // swallowed harmlessly just before they could collide with the plane.
    // Distances are measured centre-to-centre — the plane anchors at its
    // centre while obstacles anchor at their top-centre.
    if (type.isBlackHoleVacuumable && powerUps.blackHoleActive) {
      final plane = game.plane;
      final delta = plane.position -
          Vector2(position.x, position.y + size.y * .5);
      final distance = delta.length;
      if (distance > 0.5 &&
          distance < GameConfig.blackHoleObstaclePullRadius) {
        if (distance <= GameConfig.blackHoleSwallowDistance) {
          _swallowedByBlackHole();
          return;
        }
        position += delta.normalized() *
            (GameConfig.blackHoleObstaclePullSpeed * dt);
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

  /// A vacuumed hazard disappears into the vortex: a violet implosion burst,
  /// no crash, no score — the reward is the cleared sky.
  void _swallowedByBlackHole() {
    if (!_active) return;
    game.world.add(
      ColoredBurst(
        position: Vector2(position.x, position.y + size.y * .5),
        color: const Color(0xFF7C4DFF),
      ),
    );
    // Swallowed hazards award no near-miss — they never passed the plane.
    _nearMissAwarded = true;
    recycleAfterInteraction();
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

    // Phasing effects (ghost, unstable ghost) remove the risk, so they never
    // earn near-miss rewards.
    if (game.powerUpState.ghostActive ||
        game.powerUpState.unstableGhostActive) {
      return;
    }

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
    // Flame mounts freshly added hitbox children between ticks, so the
    // activation-time cache can legitimately lag one frame — top it up here.
    if (_cachedHitboxes.isEmpty) {
      refreshHitboxCache();
    }
    final planeRect = game.plane.worldAabbRect;
    var best = double.infinity;
    for (final hitbox in _cachedHitboxes) {
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

    final synergy = _activeSynergy;
    if (synergy != null) {
      final synergyPaint = Paint()
        ..color = synergy.color.withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(0, -1), radius: 16),
        animTime * 3.0,
        math.pi * 1.2,
        false,
        synergyPaint,
      );
      canvas.drawCircle(const Offset(0, -19), 2.3, synergyPaint);
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

