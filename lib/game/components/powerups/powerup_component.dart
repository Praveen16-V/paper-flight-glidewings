import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../paper_flight_game.dart';
import '../effects/coin_feedback.dart';
import '../plane_component.dart';
import 'powerup_art.dart';

/// A single power-up pickup.
///
/// Each type is drawn as *the object it actually is* — a horseshoe magnet, a
/// heater shield, a stopwatch — via [PowerUpArt], rather than a shared gift box
/// with a small glyph stamped on it. The silhouette alone identifies the
/// pickup, which matters when it is read at speed and at a glance.
///
/// Pooled and recycled by [PowerUpSpawner].
class PowerUpComponent extends PositionComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  PowerUpComponent({required this.type})
      : super(
          size: Vector2(38, 38),
          anchor: Anchor.center,
        );

  final PowerUpType type;
  CorruptedPowerUpType? corruptedType;
  bool get isCorrupted => corruptedType != null;

  bool _active = false;
  bool _collected = false;
  bool _recycleRequested = false;
  void Function(PowerUpComponent)? onRecycle;
  double _bobPhase = 0;
  double _glowPulse = 0;
  double _rotationAngle = 0;
  double _pickupAnimationElapsed = 0;

  static const double _pickupAnimationDuration = 0.26;

  void activate({
    required Vector2 spawnPosition,
    CorruptedPowerUpType? corruptedType,
    void Function(PowerUpComponent)? recycleCallback,
    int? animationSeed,
  }) {
    position = spawnPosition;
    this.corruptedType = corruptedType;
    final random = animationSeed == null ? math.Random() : math.Random(animationSeed);
    _bobPhase = random.nextDouble() * math.pi * 2;
    _glowPulse = 0;
    _rotationAngle = random.nextDouble() * math.pi * 2;
    _pickupAnimationElapsed = 0;
    _active = true;
    _collected = false;
    _recycleRequested = false;
    scale = Vector2.all(1);
    onRecycle = recycleCallback;

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(RectangleHitbox(size: size * 0.85, position: size * 0.075));
  }

  void deactivate() {
    _active = false;
    _collected = false;
    corruptedType = null;
    _recycleRequested = false;
    _pickupAnimationElapsed = 0;
    scale = Vector2.all(1);
    onRecycle = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void update(double dt) {
    if (_collected) {
      _pickupAnimationElapsed += dt;
      final progress = (_pickupAnimationElapsed / _pickupAnimationDuration)
          .clamp(0.0, 1.0)
          .toDouble();
      scale = Vector2.all(1.0 + 0.8 * progress);
      if (progress >= 1.0) _requestRecycle();
      return;
    }
    if (!_active) return;

    position.y += gameRef.scrollSpeed * dt;
    _bobPhase += dt * 2.5;
    _glowPulse += dt * 4.0;
    _rotationAngle += dt * 1.8;

    // Subtle 3D floating hover
    position.y += math.sin(_bobPhase) * 0.40;

    if (position.y > GameConfig.powerUpRecycleY) {
      _active = false;
      _requestRecycle();
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
      _collect();
    }
  }

  void _collect() {
    _collected = true;
    _active = false;
    _pickupAnimationElapsed = 0;
    _applyEffect();
  }

  void _requestRecycle() {
    if (_recycleRequested) return;
    _recycleRequested = true;
    onRecycle?.call(this);
  }

  void _applyEffect() {
    // In-world feedback is the burst only; the HUD banner names the pickup
    // and explains what it does (see applyPowerUp / applyCorruptedPowerUp).
    final corrupt = corruptedType;
    if (corrupt != null) {
      gameRef.world.add(ColoredBurst(
        position: position.clone(),
        color: corrupt.color,
      ));
      gameRef.applyCorruptedPowerUp(corrupt);
      return;
    }
    spawnPowerUpFeedback(gameRef, position, type);
    gameRef.collectPowerUp(type);
  }

  // ── Render ────────────────────────────────────────────────────────────────
  //
  // The pickup is its emblem: a floating, gently bobbing object with a tinted
  // halo behind it. No box, no wrapper — what you see is the power you get.

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = size.x * 0.36;
    final corrupt = corruptedType;

    canvas.save();
    canvas.translate(cx, cy);

    // Collection burst: the emblem flares and fades as it is absorbed.
    if (_collected) {
      final t = (_pickupAnimationElapsed / _pickupAnimationDuration)
          .clamp(0.0, 1.0)
          .toDouble();
      _drawCollectBurst(canvas, r, t, corrupt?.color ?? PowerUpArt.auraColor(type));
      canvas.restore();
      return;
    }

    // Grounding shadow, tied to the bob so the emblem reads as airborne.
    final hover = math.sin(_bobPhase).abs();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 1.75),
        width: r * 1.7 * (1.0 - hover * 0.18),
        height: r * 0.42 * (1.0 - hover * 0.18),
      ),
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    PowerUpArt.drawHalo(canvas, type, r, _glowPulse);

    // A slow tilt gives the object presence without obscuring its silhouette.
    canvas.rotate(math.sin(_rotationAngle * 0.5) * 0.10);
    PowerUpArt.draw(canvas, type, r, _glowPulse);

    if (corrupt != null) _drawCorruption(canvas, r, corrupt);

    canvas.restore();
  }

  /// Corrupted variants wear the same emblem under a cracked, oily overlay so
  /// the bargain is legible: you can still tell it is a Magnet, and you can
  /// also tell something is wrong with it.
  void _drawCorruption(Canvas canvas, double r, CorruptedPowerUpType corrupt) {
    canvas.drawCircle(
      Offset.zero,
      r * 1.12,
      Paint()..color = corrupt.color.withOpacity(0.34),
    );

    final crack = Paint()
      ..color = const Color(0xFFFFEBEE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.85, -r * 0.42)
        ..lineTo(-r * 0.18, -r * 0.06)
        ..lineTo(-r * 0.42, r * 0.30)
        ..lineTo(r * 0.30, r * 0.86),
      crack,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.80, -r * 0.62)
        ..lineTo(r * 0.22, -r * 0.14)
        ..lineTo(r * 0.58, r * 0.34),
      crack,
    );

    // Dripping corruption motes.
    for (int i = 0; i < 3; i++) {
      final t = (_glowPulse * 0.5 + i * 0.34) % 1.0;
      canvas.drawCircle(
        Offset((i - 1) * r * 0.52, r * (0.5 + t * 0.85)),
        r * 0.11 * (1 - t),
        Paint()..color = corrupt.color.withOpacity(0.85 * (1 - t)),
      );
    }
  }

  /// Absorption flash: the emblem scales up and dissolves into a ring of
  /// sparks, so a pickup always resolves with a clear "got it" beat.
  void _drawCollectBurst(Canvas canvas, double r, double t, Color tint) {
    final fade = (1.0 - t).clamp(0.0, 1.0);

    canvas.drawCircle(
      Offset.zero,
      r * (1.0 + t * 1.5),
      Paint()
        ..color = tint.withOpacity(fade * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.24 * fade,
    );

    canvas.save();
    canvas.scale(1.0 + t * 0.45);
    canvas.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: r * 2),
      Paint()..color = Colors.white.withOpacity(fade),
    );
    PowerUpArt.draw(canvas, type, r, _glowPulse);
    canvas.restore();
    canvas.restore();

    final spark = Paint()..color = tint.withOpacity(fade);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + _rotationAngle;
      final d = r * (0.9 + t * 1.8);
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d),
        r * 0.16 * fade,
        spark,
      );
    }
  }
}
