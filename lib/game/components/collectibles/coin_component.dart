import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
import '../../../providers/game_session_provider.dart';
import '../../../providers/save_data_provider.dart';
import '../../paper_flight_game.dart';
import '../effects/coin_feedback.dart';
import '../plane_component.dart';

enum CollectibleVariant {
  standardCoin, // Classic 28px gold coin
  stack5x,      // 5x gold coin stack (+50 pts / 5 coins)
  gem3D,        // 3D Isometric Blue Gem (+1 Gem)
  letterTile,   // Origami Letter Tile (Word Bonus progress)
}

/// A collectible pickup (Coins, 5x Stacks, 3D Gems, Origami Letters).
class CoinComponent extends CircleComponent
    with HasGameRef<PaperFlightGame>, CollisionCallbacks {
  CoinComponent({this.variant = CollectibleVariant.standardCoin})
      : super(
          radius: GameConfig.coinSize / 2,
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFFFFD700),
        );

  CollectibleVariant variant;
  String letter = 'P';

  bool _active = false;
  bool _collected = false;
  void Function(CoinComponent)? onRecycle;

  double _bobPhase = 0;
  double _rotationAngle = 0;

  void activate({
    required Vector2 spawnPosition,
    CollectibleVariant variant = CollectibleVariant.standardCoin,
    String letter = 'P',
    void Function(CoinComponent)? recycleCallback,
  }) {
    position = spawnPosition;
    this.variant = variant;
    this.letter = letter;
    _bobPhase = MathUtils.randomRange(0, math.pi * 2);
    _rotationAngle = MathUtils.randomRange(0, math.pi * 2);
    _active = true;
    _collected = false;
    onRecycle = recycleCallback;
    scale = Vector2.all(1);
    paint.color = const Color(0xFFFFD700);

    removeAll(children.whereType<ShapeHitbox>().toList());
    add(CircleHitbox(radius: radius + 4));
  }

  void deactivate() {
    _active = false;
    _collected = false;
    scale = Vector2.all(1);
    onRecycle = null;
    removeAll(children.whereType<ShapeHitbox>().toList());
  }

  @override
  void update(double dt) {
    if (!_active || _collected) return;

    position.y += game.scrollSpeed * dt;
    _bobPhase += dt * 3.0;
    _rotationAngle += dt * 2.0;

    position.y += math.sin(_bobPhase) * 0.4;

    // Magnet pull
    final session = gameRef.ref.read(gameSessionProvider);
    final plane = gameRef.plane;
    if (plane.planeType == PlaneType.interceptor) {
      // Interceptor downside: no coin attraction
    } else if (session.activePowerUps.contains(PowerUpType.magnet)) {
      final dist = MathUtils.distance(
        position.x, position.y,
        plane.position.x, plane.position.y,
      );
      if (dist < GameConfig.coinMagnetRadius) {
        final dir = (plane.position - position).normalized();
        position += dir * (GameConfig.coinMagnetPullSpeed * dt);
      }
    } else if (plane.planeType == PlaneType.glider) {
      final rAttract = plane.planeLevel >= 3 ? 160.0 : (plane.planeLevel == 2 ? 125.0 : GameConfig.gliderCoinAttractRadius);
      final sAttract = plane.planeLevel >= 3 ? 220.0 : (plane.planeLevel == 2 ? 180.0 : GameConfig.gliderCoinAttractSpeed);
      final dist = MathUtils.distance(
        position.x, position.y,
        plane.position.x, plane.position.y,
      );
      if (dist < rAttract) {
        final dir = (plane.position - position).normalized();
        position += dir * (sAttract * dt);
      }
    }

    if (position.y > GameConfig.coinRecycleY) {
      _active = false;
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
      _collect();
    }
  }

  void _collect() {
    _collected = true;
    _active = false;

    switch (variant) {
      case CollectibleVariant.standardCoin:
        final points = gameRef.scoringSystem.onCoinCollected();
        spawnCoinFeedback(gameRef, position, points);
        break;

      case CollectibleVariant.stack5x:
        // 5x coin stack reward
        int totalPts = 0;
        for (int i = 0; i < 5; i++) {
          totalPts += gameRef.scoringSystem.onCoinCollected();
        }
        final world = gameRef.world;
        world.add(ColoredBurst(position: position.clone(), color: const Color(0xFFFFD700)));
        world.add(
          FloatingScoreText(
            position: position.clone(),
            text: '5X STACK! +$totalPts',
            color: const Color(0xFFFFD700),
            fontSize: 20,
          ),
        );
        break;

      case CollectibleVariant.gem3D:
        // 3D Gem pickup (+1 Gem awarded to save data)
        try {
          gameRef.ref.read(saveDataProvider.notifier).addGems(1);
        } catch (_) {}
        final world = gameRef.world;
        world.add(ColoredBurst(position: position.clone(), color: const Color(0xFF00E5FF)));
        world.add(
          FloatingScoreText(
            position: position.clone(),
            text: '+1 GEM!',
            color: const Color(0xFF00E5FF),
            fontSize: 22,
          ),
        );
        gameRef.gameFeelSystem.onCoinCollected(10);
        break;

      case CollectibleVariant.letterTile:
        // Origami Letter Tile collected
        gameRef.scoringSystem.awardComboNotches(2.0);
        final world = gameRef.world;
        world.add(ColoredBurst(position: position.clone(), color: const Color(0xFFFF80AB)));
        world.add(
          FloatingScoreText(
            position: position.clone(),
            text: 'LETTER [$letter]!',
            color: const Color(0xFFFF80AB),
            fontSize: 19,
          ),
        );
        gameRef.gameFeelSystem.onCoinCollected(15);
        break;
    }

    add(ScaleEffect.by(
      Vector2.all(1.5),
      EffectController(duration: 0.08, reverseDuration: 0.06),
    ));
    add(OpacityEffect.fadeOut(
      EffectController(duration: 0.18),
      onComplete: () => onRecycle?.call(this),
    ));
  }

  @override
  void render(Canvas canvas) {
    switch (variant) {
      case CollectibleVariant.standardCoin:
        _drawStandardCoin(canvas);
        break;
      case CollectibleVariant.stack5x:
        _draw5xCoinStack(canvas);
        break;
      case CollectibleVariant.gem3D:
        _draw3dBlueGem(canvas);
        break;
      case CollectibleVariant.letterTile:
        _drawLetterTile(canvas);
        break;
    }
  }

  void _drawStandardCoin(Canvas canvas) {
    final outerPaint = Paint()..color = const Color(0xFFFFD700);
    final innerPaint = Paint()..color = const Color(0xFFFFC107);
    final highlightPaint = Paint()..color = const Color(0xFFFFFF8D)..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, radius, outerPaint);
    canvas.drawCircle(Offset.zero, radius * 0.7, innerPaint);
    canvas.drawCircle(Offset(-radius * 0.3, -radius * 0.3), radius * 0.15, highlightPaint);
  }

  void _draw5xCoinStack(Canvas canvas) {
    final goldBase = Paint()..color = const Color(0xFFFFA000);
    final goldFace = Paint()..color = const Color(0xFFFFD700);
    final goldHi = Paint()..color = const Color(0xFFFFFF8D);

    // 3 stacked isometric golden disks
    for (int i = 0; i < 3; i++) {
      final dy = 4.0 - (i * 4.0);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, dy + 2), width: radius * 2.2, height: radius * 1.3), goldBase);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, dy), width: radius * 2.2, height: radius * 1.3), goldFace);
    }
    canvas.drawCircle(const Offset(-4, -6), 2.2, goldHi);

    // "5X" Badge stamp
    final tp = TextPainter(
      text: const TextSpan(
        text: '5X',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFF5D4037),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 - 4));
  }

  void _draw3dBlueGem(Canvas canvas) {
    final tilt = math.sin(_rotationAngle) * 0.12;
    canvas.save();
    canvas.rotate(tilt);

    final r = radius * 1.1;

    // Faceted 3D Diamond Gem
    final topFacet = Path()..moveTo(0, -r)..lineTo(r * 0.85, -r * 0.35)..lineTo(0, 0)..lineTo(-r * 0.85, -r * 0.35)..close();
    final leftFacet = Path()..moveTo(-r * 0.85, -r * 0.35)..lineTo(0, 0)..lineTo(0, r)..lineTo(-r * 0.85, -r * 0.35)..close();
    final rightFacet = Path()..moveTo(r * 0.85, -r * 0.35)..lineTo(0, 0)..lineTo(0, r)..lineTo(r * 0.85, -r * 0.35)..close();

    canvas.drawPath(topFacet, Paint()..color = const Color(0xFF80DEEA));
    canvas.drawPath(leftFacet, Paint()..color = const Color(0xFF00ACC1));
    canvas.drawPath(rightFacet, Paint()..color = const Color(0xFF00838F));

    // Specular glint
    canvas.drawCircle(Offset(0, -r * 0.5), 2.0, Paint()..color = Colors.white);

    canvas.restore();
  }

  void _drawLetterTile(Canvas canvas) {
    final r = radius * 1.1;

    // Folded parchment square
    final bgPaint = Paint()..color = const Color(0xFFFFF8E1)..style = PaintingStyle.fill;
    final rimPaint = Paint()..color = const Color(0xFFFF80AB)..style = PaintingStyle.stroke..strokeWidth = 1.4;

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), const Radius.circular(4)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), const Radius.circular(4)), rimPaint);

    // Letter Glyph
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF880E4F),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}
