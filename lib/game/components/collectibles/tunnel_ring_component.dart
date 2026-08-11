import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../paper_flight_game.dart';
import '../effects/coin_feedback.dart';
import '../plane_component.dart';

/// Outcome reported to a linked ring run as soon as this gate is resolved.
enum TunnelRingResult { perfect, clear, missed }

typedef TunnelRingResolutionCallback = void Function(
  TunnelRingComponent ring,
  TunnelRingResult result,
);

/// An origami tunnel gate with standard, narrow precision, and drifting forms.
///
/// Only the visible aperture carries a hitbox, so a ring is a genuine flight
/// line to thread rather than a wide collectible rectangle. Linked runs report
/// every pass/miss to their owning spawner through [onResolved].
class TunnelRingComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  TunnelRingComponent()
      : super(
          size: Vector2(120, 36),
          anchor: Anchor.center,
        );

  bool _active = false;
  bool _collected = false;
  bool _resolved = false;
  void Function(TunnelRingComponent)? onRecycle;
  TunnelRingResolutionCallback? onResolved;

  TunnelRingVariant variant = TunnelRingVariant.standard;
  int? chainId;
  int chainIndex = 0;
  int chainLength = 1;

  double _animTime = 0.0;
  double _ringPulse = 0.0;
  double _driftPhase = 0.0;
  double _spawnX = 0.0;

  bool get isActive => _active;
  bool get isChained => chainId != null && chainLength > 1;
  bool get isPrecision => variant == TunnelRingVariant.precision;
  bool get isDrifting => variant == TunnelRingVariant.drifting;

  double get perfectClearHalfWidth => switch (variant) {
        TunnelRingVariant.precision =>
          GameConfig.tunnelRingPrecisionPerfectHalfWidth,
        TunnelRingVariant.standard || TunnelRingVariant.drifting =>
          GameConfig.tunnelRingStandardPerfectHalfWidth,
      };

  void activate({
    required Vector2 spawnPosition,
    void Function(TunnelRingComponent)? recycleCallback,
    TunnelRingVariant variant = TunnelRingVariant.standard,
    int? chainId,
    int chainIndex = 0,
    int chainLength = 1,
    TunnelRingResolutionCallback? resolutionCallback,
    int? randomSeed,
  }) {
    this.variant = variant;
    this.chainId = chainId;
    this.chainIndex = chainIndex;
    this.chainLength = chainLength < 1 ? 1 : chainLength;
    onResolved = resolutionCallback;

    final scaleFactor = switch (variant) {
      TunnelRingVariant.standard => 1.0,
      TunnelRingVariant.precision => GameConfig.tunnelRingPrecisionScale,
      TunnelRingVariant.drifting => GameConfig.tunnelRingDriftingScale,
    };
    size = Vector2(120 * scaleFactor, 36 * scaleFactor);
    position = spawnPosition;
    _spawnX = spawnPosition.x;
    final random = randomSeed == null ? math.Random() : math.Random(randomSeed);
    _animTime = random.nextDouble() * math.pi * 2;
    _driftPhase = random.nextDouble() * math.pi * 2;
    _ringPulse = 0.0;
    _active = true;
    _collected = false;
    _resolved = false;
    scale = Vector2.all(1);
    onRecycle = recycleCallback;

    removeAll(children.whereType<ShapeHitbox>().toList());
    final aperture = Vector2(
      size.x * GameConfig.tunnelRingApertureWidthFraction,
      size.y * GameConfig.tunnelRingApertureHeightFraction,
    );
    add(RectangleHitbox(
      size: aperture,
      position: (size - aperture) / 2,
    ));
  }

  void deactivate() {
    _active = false;
    _collected = false;
    _resolved = false;
    chainId = null;
    chainIndex = 0;
    chainLength = 1;
    variant = TunnelRingVariant.standard;
    scale = Vector2.all(1);
    onRecycle = null;
    onResolved = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void update(double dt) {
    if (_collected) {
      _ringPulse += dt * 4.0;
      scale = Vector2.all(1.0 + _ringPulse * 0.7);
      if (_ringPulse >= 1.0) {
        _active = false;
        onRecycle?.call(this);
      }
      return;
    }
    if (!_active) return;

    position.y += gameRef.scrollSpeed * dt;
    _animTime += dt;
    if (isDrifting) {
      position.x = (_spawnX +
              math.sin(_driftPhase +
                      _animTime * GameConfig.tunnelRingDriftAngularSpeed) *
                  GameConfig.tunnelRingDriftAmplitude)
          .clamp(
            GameConfig.horizontalEdgeMargin + size.x * .5,
            GameConfig.designWidth -
                GameConfig.horizontalEdgeMargin -
                size.x * .5,
          )
          .toDouble();
    }

    if (position.y > GameConfig.coinRecycleY + 40) {
      _active = false;
      _resolve(TunnelRingResult.missed);
      onRecycle?.call(this);
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (!_active || _collected) return;
    if (other is PlaneComponent) {
      _passThrough(other);
    }
  }

  void _passThrough(PlaneComponent plane) {
    _collected = true;
    _active = false;
    _ringPulse = 0.0;

    final dxFromCenter = (plane.position.x - position.x).abs();
    final isPerfectClear = dxFromCenter <= perfectClearHalfWidth;
    final result = isPerfectClear
        ? TunnelRingResult.perfect
        : TunnelRingResult.clear;
    _applyReward(result);
    _resolve(result);
  }

  void _resolve(TunnelRingResult result) {
    if (_resolved) return;
    _resolved = true;
    onResolved?.call(this, result);
  }

  void _applyReward(TunnelRingResult result) {
    final world = gameRef.world;
    if (result == TunnelRingResult.perfect) {
      final comboNotches = isPrecision
          ? GameConfig.tunnelRingPrecisionComboNotches
          : GameConfig.tunnelRingPerfectComboNotches;
      gameRef.scoringSystem.awardComboNotches(comboNotches);
      gameRef.inputManager.restoreSnapCharge(1);
      gameRef.gameFeelSystem.onCoinCollected(gameRef.scoringSystem.comboCount);

      final label = isPrecision
          ? 'PRECISION! +BOOST'
          : isDrifting
              ? 'DRIFT PERFECT! +BOOST'
              : 'PERFECT CLEAR! +BOOST';
      final color = isPrecision
          ? const Color(0xFFE1BEE7)
          : isDrifting
              ? const Color(0xFF80DEEA)
              : const Color(0xFFFFD700);
      world.add(ColoredBurst(position: position.clone(), color: color));
      world.add(
        FloatingScoreText(
          position: position.clone(),
          text: label,
          color: color,
          fontSize: isPrecision ? 22 : 20,
        ),
      );
      return;
    }

    gameRef.scoringSystem
        .awardComboNotches(GameConfig.tunnelRingClearComboNotches);
    gameRef.gameFeelSystem.onCoinCollected(gameRef.scoringSystem.comboCount);
    world.add(
      ColoredBurst(
        position: position.clone(),
        color: const Color(0xFF4FC3F7),
      ),
    );
    world.add(
      FloatingScoreText(
        position: position.clone(),
        text: 'RING CLEAR! +2 COMBO',
        color: const Color(0xFF4FC3F7),
        fontSize: 16,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final rx = size.x * 0.48;
    final ry = size.y * 0.46;
    final pulse = (math.sin(_animTime * 5.0) * 0.5 + 0.5);
    final accent = switch (variant) {
      TunnelRingVariant.standard => const Color(0xFFF5A623),
      TunnelRingVariant.precision => const Color(0xFFCE93D8),
      TunnelRingVariant.drifting => const Color(0xFF4DD0E1),
    };

    // 1. Glowing portal aperture.
    final portalPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withOpacity(0.40 + 0.25 * pulse),
          const Color(0x3300E5FF),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.2, height: ry * 2.2),
      )
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.0, height: ry * 2.0),
      portalPaint,
    );

    // 2. Folded paper torus.
    final outerRing = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = isPrecision ? 3.0 : 3.6;
    final innerHighlight = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final shadowBevel = Paint()
      ..color = const Color(0xFF4E342E).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final oval = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    canvas.drawOval(oval, outerRing);
    canvas.drawOval(oval.shift(const Offset(-1, -1)), innerHighlight);
    canvas.drawOval(oval.shift(const Offset(1, 1)), shadowBevel);

    // Precision rings use a tight secondary aperture; drift rings show their
    // lateral wind cue so movement is never a hidden rule.
    if (isPrecision) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.18, height: ry * 1.18),
        Paint()
          ..color = accent.withOpacity(.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
    if (isDrifting) {
      final driftPaint = Paint()
        ..color = accent.withOpacity(.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.45, height: ry * 1.55),
        _animTime * 4.0,
        math.pi * 1.3,
        false,
        driftPaint,
      );
    }

    // 3. Side brackets and central guidance arrow.
    final bracketPaint = Paint()..color = accent..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - rx, cy), 3.5, bracketPaint);
    canvas.drawCircle(Offset(cx + rx, cy), 3.5, bracketPaint);
    final target = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 0.7 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final chevY = cy + (pulse * 3.0 - 1.5);
    canvas.drawLine(Offset(cx - 6, chevY - 3), Offset(cx, chevY + 4), target);
    canvas.drawLine(Offset(cx + 6, chevY - 3), Offset(cx, chevY + 4), target);

    _drawChainPips(canvas, cx, cy + ry + 9, accent);
  }

  void _drawChainPips(Canvas canvas, double cx, double y, Color accent) {
    if (!isChained) return;
    final startX = cx - (chainLength - 1) * 5.0;
    for (var i = 0; i < chainLength; i++) {
      final filled = i <= chainIndex;
      canvas.drawCircle(
        Offset(startX + i * 10.0, y),
        2.4,
        Paint()
          ..color = filled ? accent : accent.withOpacity(.22)
          ..style = PaintingStyle.fill,
      );
    }
  }
}
