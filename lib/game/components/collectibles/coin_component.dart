import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/math_utils.dart';
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

/// Shared glyph painters — coins are rendered in bulk, so their text is laid
/// out once here instead of per frame in every pooled component.
final TextPainter _stack5xBadge = TextPainter(
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

/// One cached painter per letter tile glyph (the spawner only ever uses the
/// letters of PAPERFLIGHT).
final Map<String, TextPainter> _letterTileGlyphs = {};

TextPainter _letterTilePainter(String letter) {
  return _letterTileGlyphs.putIfAbsent(
    letter,
    () => TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF880E4F),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
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
    int? animationSeed,
  }) {
    position = spawnPosition;
    this.variant = variant;
    this.letter = letter;
    final random = animationSeed == null ? math.Random() : math.Random(animationSeed);
    _bobPhase = random.nextDouble() * math.pi * 2;
    _rotationAngle = random.nextDouble() * math.pi * 2;
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

    // Coin attraction. All live power-up flags come from the game's
    // once-per-frame cache — no provider reads in the coin hot path.
    final powerUps = gameRef.powerUpState;
    final plane = gameRef.plane;
    if (powerUps.cursedMagnetActive) {
      // Cursed Magnet overrides normal plane drawbacks and pulls every
      // collectible harder, while its obstacle pull creates the danger.
      final dist = MathUtils.distance(
        position.x, position.y,
        plane.position.x, plane.position.y,
      );
      if (dist < GameConfig.cursedMagnetRadius) {
        final dir = (plane.position - position).normalized();
        position += dir * (GameConfig.cursedMagnetCoinPullSpeed * dt);
      }
    } else if (powerUps.blackHoleActive) {
      // Black Hole vacuum: the widest, hardest pull in the game. Collectibles
      // are swallowed once they reach the vortex core — even gems, which a
      // plain Magnet Lv2 would only auto-collect with its own radius.
      final dist = MathUtils.distance(
        position.x, position.y,
        plane.position.x, plane.position.y,
      );
      if (dist < GameConfig.blackHoleCoinPullRadius) {
        if (dist <= GameConfig.blackHoleCoinCollectDistance) {
          _collect();
          return;
        }
        final dir = (plane.position - position).normalized();
        position += dir * (GameConfig.blackHoleCoinPullSpeed * dt);
      }
    } else if (plane.planeType == PlaneType.interceptor) {
      // Interceptor downside: no coin attraction
    } else if (powerUps.magnetActive) {
      final magnetLevel = powerUps.magnetLevel;
      final radius = magnetLevel >= 2
          ? GameConfig.magnetLevel2Radius
          : GameConfig.coinMagnetRadius;
      final pullSpeed = magnetLevel >= 2
          ? GameConfig.magnetLevel2PullSpeed
          : GameConfig.coinMagnetPullSpeed;
      final dist = MathUtils.distance(
        position.x, position.y,
        plane.position.x, plane.position.y,
      );
      if (variant == CollectibleVariant.gem3D &&
          magnetLevel >= 2 &&
          dist < GameConfig.magnetLevel2GemAutoCollectRadius) {
        _collect();
        return;
      }
      if (dist < radius) {
        final dir = (plane.position - position).normalized();
        position += dir * (pullSpeed * dt);
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
    // Cylinder edge: dark rim below the face sells a solid coin.
    canvas.drawCircle(Offset(0, radius * 0.14), radius,
        Paint()..color = const Color(0xFFB8860B));
    // Metallic radial sheen across the face.
    final faceRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.05,
          colors: const [Color(0xFFFFF176), Color(0xFFFFC107), Color(0xFFB8860B)],
          stops: const [0.0, .55, 1.0],
        ).createShader(faceRect),
    );
    // Embossed inner ring.
    canvas.drawCircle(
      Offset.zero,
      radius * 0.74,
      Paint()
        ..color = const Color(0xFFB8860B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Specular glint.
    canvas.drawCircle(Offset(-radius * 0.3, -radius * 0.34), radius * 0.18,
        Paint()..color = const Color(0xCCFFFFFF));
    canvas.drawCircle(Offset(-radius * 0.3, -radius * 0.34), radius * 0.09,
        Paint()..color = const Color(0xFFFFFFFF));
  }

  void _draw5xCoinStack(Canvas canvas) {
    final goldHi = Paint()..color = const Color(0xFFFFFF8D);

    // 3 stacked isometric golden disks with edge depth + specular top.
    for (int i = 0; i < 3; i++) {
      final dy = 4.0 - (i * 4.0);
      final edgeRect = Rect.fromCenter(center: Offset(0, dy + 3), width: radius * 2.2, height: radius * 1.3);
      canvas.drawOval(edgeRect, Paint()..color = const Color(0xFF8B5E00));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, dy), width: radius * 2.2, height: radius * 1.3),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF176), Color(0xFFFFC107), Color(0xFFB8860B)],
            stops: [0.0, .5, 1.0],
          ).createShader(edgeRect),
      );
    }
    canvas.drawCircle(const Offset(-4, -6), 2.2, goldHi);

    // "5X" Badge stamp
    _stack5xBadge.paint(
      canvas,
      Offset(-_stack5xBadge.width / 2, -_stack5xBadge.height / 2 - 4),
    );
  }

  void _draw3dBlueGem(Canvas canvas) {
    final tilt = math.sin(_rotationAngle) * 0.12;
    canvas.save();
    canvas.rotate(tilt);

    final r = radius * 1.1;

    // Soft glow halo behind the gem.
    canvas.drawCircle(
      Offset.zero,
      r * 1.3,
      Paint()
        ..color = const Color(0x3300E5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Faceted 3D Diamond Gem with gradient facets.
    final topFacet = Path()..moveTo(0, -r)..lineTo(r * 0.85, -r * 0.35)..lineTo(0, 0)..lineTo(-r * 0.85, -r * 0.35)..close();
    final leftFacet = Path()..moveTo(-r * 0.85, -r * 0.35)..lineTo(0, 0)..lineTo(0, r)..lineTo(-r * 0.85, -r * 0.35)..close();
    final rightFacet = Path()..moveTo(r * 0.85, -r * 0.35)..lineTo(0, 0)..lineTo(0, r)..lineTo(r * 0.85, -r * 0.35)..close();
    final gemRect = Rect.fromCircle(center: Offset.zero, radius: r);

    canvas.drawPath(
      topFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F7FA), Color(0xFF4DD0E1)],
        ).createShader(gemRect),
    );
    canvas.drawPath(
      leftFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF26C6DA), Color(0xFF00838F)],
        ).createShader(gemRect),
    );
    canvas.drawPath(
      rightFacet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00838F), Color(0xFF004D57)],
        ).createShader(gemRect),
    );

    // Facet edge lines for a crisp cut.
    final edge = Paint()
      ..color = const Color(0x44FFFFFF)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topFacet, edge);
    canvas.drawPath(leftFacet, edge);
    canvas.drawPath(rightFacet, edge);

    // Specular glint
    canvas.drawCircle(Offset(-r * 0.3, -r * 0.55), 2.4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(r * 0.15, r * 0.3), 1.2, Paint()..color = const Color(0x99FFFFFF));

    canvas.restore();
  }

  void _drawLetterTile(Canvas canvas) {
    final r = radius * 1.1;

    // Folded parchment square with a 3D shadowed base for lift.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(2, 3), width: r * 2, height: r * 2), const Radius.circular(4)),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    final tileRect = Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tileRect, const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFEF6), Color(0xFFFFF3C4), Color(0xFFE8C77A)],
          stops: const [0.0, .5, 1.0],
        ).createShader(tileRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tileRect, const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFFFF80AB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Top-left catch light.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-r * .8, -r * .8, r * .5, r * .5), const Radius.circular(2)),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Letter Glyph
    final tp = _letterTilePainter(letter);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}
