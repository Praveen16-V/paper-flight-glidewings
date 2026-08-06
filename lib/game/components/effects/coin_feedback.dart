import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/painting.dart';

import '../../../core/enums/game_enums.dart';
import '../../paper_flight_game.dart';

/// Spawns a satisfying coin-pickup feedback at [position] on the [game]: a gold
/// sparkle burst plus a floating "+points" text that drifts up and fades out.
void spawnCoinFeedback(
  PaperFlightGame game,
  Vector2 position,
  int points,
) {
  final world = game.world;
  world.add(CoinSparkleBurst(position: position.clone()));
  world.add(
    FloatingScoreText(
      position: position.clone(),
      text: '+$points',
    ),
  );
  _playSfx('coin_collect.mp3');
}

/// Spawns an energetic near-miss feedback at [position]: golden/cyan spark burst,
/// floating "+points NEAR MISS!" banner, and audio sting.
void spawnNearMissFeedback(
  PaperFlightGame game,
  Vector2 position,
  int points,
) {
  final world = game.world;
  world.add(NearMissSparkleBurst(position: position.clone()));
  world.add(
    FloatingScoreText(
      position: position.clone(),
      text: '+$points NEAR MISS!',
      color: const Color(0xFFFFEB3B),
      fontSize: 20,
    ),
  );
  _playSfx('near_miss.mp3');
}

/// Spawns an origami crash explosion: fluttering paper shreds, shockwave ring,
/// and crash audio sting.
void spawnCrashFeedback(
  PaperFlightGame game,
  Vector2 position,
) {
  final world = game.world;
  world.add(CrashShockwaveRing(position: position.clone()));
  world.add(PaperCrashBurst(position: position.clone()));
  _playSfx('crash.mp3');
}

/// Spawns a satisfying power-up pickup: a colored energy burst in the
/// power-up's signature color plus a floating banner announcing its name.
void spawnPowerUpFeedback(
  PaperFlightGame game,
  Vector2 position,
  PowerUpType type,
) {
  final world = game.world;
  world.add(ColoredBurst(position: position.clone(), color: _powerUpColor(type)));
  world.add(
    FloatingScoreText(
      position: position.clone(),
      text: type.displayName.toUpperCase(),
      color: _powerUpColor(type),
      fontSize: 22,
    ),
  );
  _playSfx('powerup_pickup.mp3');
}

Color _powerUpColor(PowerUpType type) {
  switch (type) {
    case PowerUpType.shield:
      return const Color(0xFF64B5F6); // blue
    case PowerUpType.magnet:
      return const Color(0xFFAB47BC); // purple
    case PowerUpType.ghost:
      return const Color(0xFF80DEEA); // cyan
    case PowerUpType.slowMo:
      return const Color(0xFF26A69A); // teal
    case PowerUpType.coinRush:
      return const Color(0xFFFFD700); // gold
  }
}

void _playSfx(String fileName) {
  try {
    FlameAudio.play(fileName);
  } catch (_) {
    // Audio playback safely ignored if asset is silent or unsupported in test.
  }
}

/// A quick radial burst of sparks in a given color, used for power-up pickups.
class ColoredBurst extends PositionComponent {
  ColoredBurst({required super.position, required this.color});

  final Color color;
  static const int _count = 16;
  static const double _life = 0.55;
  static const double _speed = 160.0;

  final List<_StarParticle> _particles = [];
  double _elapsed = 0;

  @override
  void onLoad() {
    for (int i = 0; i < _count; i++) {
      final angle = math.Random().nextDouble() * math.pi * 2;
      final speed = _speed * (0.4 + math.Random().nextDouble() * 0.8);
      _particles.add(
        _StarParticle(
          dir: Vector2(math.cos(angle), math.sin(angle)) * speed,
          size: 3.0 + math.Random().nextDouble() * 4.0,
          color: i.isEven ? color : const Color(0xFFFFFFFF),
          rotation: math.Random().nextDouble() * math.pi * 2,
          rotSpeed: (math.Random().nextDouble() - 0.5) * 9.0,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _life) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.pos.add(p.dir * dt);
      p.rotation += p.rotSpeed * dt;
      p.dir *= (1 - 2.0 * dt);
      p.size *= (1 - 2.0 * dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _life).clamp(0.0, 1.0);
    final alpha = (1.0 - t).clamp(0.0, 1.0);
    for (final p in _particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(p.pos.x, p.pos.y);
      canvas.rotate(p.rotation);
      final s = p.size.clamp(0.1, 10.0);
      final path = Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.35, 0)
        ..lineTo(0, s)
        ..lineTo(-s * 0.35, 0)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }
}

// ── Particle Components ───────────────────────────────────────────────────────

/// A quick burst of gold particles that fly outward and shrink away.
class CoinSparkleBurst extends PositionComponent {
  CoinSparkleBurst({required super.position});

  static const int _count = 10;
  static const double _life = 0.5; // seconds
  static const double _speed = 120.0; // px/s

  final List<_Particle> _particles = [];
  double _elapsed = 0;

  @override
  void onLoad() {
    for (int i = 0; i < _count; i++) {
      final angle = math.Random().nextDouble() * math.pi * 2;
      final speed = _speed * (0.5 + math.Random().nextDouble());
      _particles.add(
        _Particle(
          dir: Vector2(math.cos(angle), math.sin(angle)) * speed,
          size: 2.0 + math.Random().nextDouble() * 2.5,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _life) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.pos.add(p.dir * dt);
      p.dir *= (1 - 2.0 * dt); // decelerate outward
      p.size *= (1 - 2.5 * dt); // shrink
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _life).clamp(0.0, 1.0);
    for (final p in _particles) {
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.fromRGBO(255, 215, 0, alpha) // gold
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.pos.toOffset(), p.size.clamp(0.1, 8.0), paint);
    }
  }
}

/// Starburst of cyan, gold, and white sparks for near misses.
class NearMissSparkleBurst extends PositionComponent {
  NearMissSparkleBurst({required super.position});

  static const int _count = 16;
  static const double _life = 0.6;
  static const double _speed = 170.0;

  final List<_StarParticle> _particles = [];
  double _elapsed = 0;

  @override
  void onLoad() {
    for (int i = 0; i < _count; i++) {
      final angle = math.Random().nextDouble() * math.pi * 2;
      final speed = _speed * (0.4 + math.Random().nextDouble() * 0.8);
      final isGold = i.isEven;
      _particles.add(
        _StarParticle(
          dir: Vector2(math.cos(angle), math.sin(angle)) * speed,
          size: 3.0 + math.Random().nextDouble() * 3.5,
          color: isGold
              ? const Color(0xFFFFD700)
              : const Color(0xFF4FC3F7),
          rotation: math.Random().nextDouble() * math.pi * 2,
          rotSpeed: (math.Random().nextDouble() - 0.5) * 8.0,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _life) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.pos.add(p.dir * dt);
      p.rotation += p.rotSpeed * dt;
      p.dir *= (1 - 2.2 * dt);
      p.size *= (1 - 1.8 * dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _life).clamp(0.0, 1.0);
    final alpha = (1.0 - t).clamp(0.0, 1.0);

    for (final p in _particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.pos.x, p.pos.y);
      canvas.rotate(p.rotation);

      // Draw diamond / 4-point spark
      final s = p.size.clamp(0.1, 10.0);
      final path = Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.35, 0)
        ..lineTo(0, s)
        ..lineTo(-s * 0.35, 0)
        ..close();
      canvas.drawPath(path, paint);

      canvas.restore();
    }
  }
}

/// Paper origami fragments bursting and fluttering outward on crash.
class PaperCrashBurst extends PositionComponent {
  PaperCrashBurst({required super.position});

  static const int _count = 20;
  static const double _life = 1.0;

  final List<_PaperShred> _shreds = [];
  double _elapsed = 0;

  @override
  void onLoad() {
    final colors = [
      const Color(0xFFF5A623), // Plane accent gold
      const Color(0xFFFFFFFF), // Paper white
      const Color(0xFFE0E0E0), // Fold shadow gray
      const Color(0xFFFF5252), // Danger red
      const Color(0xFFFFD54F), // Light amber
    ];

    for (int i = 0; i < _count; i++) {
      final angle = math.Random().nextDouble() * math.pi * 2;
      final speed = 80.0 + math.Random().nextDouble() * 200.0;
      _shreds.add(
        _PaperShred(
          pos: Vector2.zero(),
          velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed - 60),
          width: 5.0 + math.Random().nextDouble() * 7.0,
          height: 8.0 + math.Random().nextDouble() * 10.0,
          color: colors[i % colors.length],
          angle: math.Random().nextDouble() * math.pi * 2,
          angularVelocity: (math.Random().nextDouble() - 0.5) * 12.0,
          flutterFreq: 4.0 + math.Random().nextDouble() * 6.0,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _life) {
      removeFromParent();
      return;
    }
    for (final s in _shreds) {
      s.velocity.y += 180.0 * dt; // gravity pulling paper down
      s.velocity.x *= (1.0 - 1.2 * dt); // air drag
      s.pos.add(s.velocity * dt);
      s.angle += s.angularVelocity * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _life).clamp(0.0, 1.0);
    final alpha = (1.0 - t * t).clamp(0.0, 1.0);

    for (final s in _shreds) {
      final paint = Paint()
        ..color = s.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(s.pos.x, s.pos.y);
      canvas.rotate(s.angle);
      // Perspective fold simulation via scaleX
      final foldScale = math.sin(_elapsed * s.flutterFreq);
      canvas.scale(foldScale.abs().clamp(0.1, 1.0), 1.0);

      // Triangular / polygon paper shard
      final path = Path()
        ..moveTo(-s.width / 2, -s.height / 2)
        ..lineTo(s.width / 2, -s.height / 4)
        ..lineTo(s.width / 3, s.height / 2)
        ..lineTo(-s.width / 3, s.height / 3)
        ..close();
      canvas.drawPath(path, paint);

      canvas.restore();
    }
  }
}

/// Circular expanding shockwave on crash.
class CrashShockwaveRing extends PositionComponent {
  CrashShockwaveRing({required super.position});

  static const double _life = 0.45;
  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _life) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _life).clamp(0.0, 1.0);
    final radius = 10.0 + t * 90.0;
    final alpha = (1.0 - t).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = Color.fromRGBO(255, 200, 100, alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 - t) * 4.0 + 1.0;

    canvas.drawCircle(Offset.zero, radius, paint);
  }
}

class _Particle {
  _Particle({required this.dir, required this.size});
  final Vector2 pos = Vector2.zero();
  Vector2 dir;
  double size;
}

class _StarParticle {
  _StarParticle({
    required this.dir,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotSpeed,
  });
  final Vector2 pos = Vector2.zero();
  Vector2 dir;
  double size;
  Color color;
  double rotation;
  double rotSpeed;
}

class _PaperShred {
  _PaperShred({
    required this.pos,
    required this.velocity,
    required this.width,
    required this.height,
    required this.color,
    required this.angle,
    required this.angularVelocity,
    required this.flutterFreq,
  });
  Vector2 pos;
  Vector2 velocity;
  double width;
  double height;
  Color color;
  double angle;
  double angularVelocity;
  double flutterFreq;
}

/// A "+points" label that pops in, floats upward, and fades out.
class FloatingScoreText extends PositionComponent {
  FloatingScoreText({
    required super.position,
    required this.text,
    this.color = const Color(0xFFFFD700),
    this.fontSize = 18,
  });

  final String text;
  final Color color;
  final double fontSize;

  double _elapsed = 0;
  static const double _life = 0.85; // seconds
  static const double _rise = 60.0; // px total

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _life) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _life).clamp(0.0, 1.0);

    // Pop-in scale at the start (0 → 1 quickly), then settle.
    final scaleIn = _Curves.easeOutBack((t * 3).clamp(0.0, 1.0));
    final alpha = 1.0 - _Curves.easeIn(t.clamp(0.0, 1.0));

    final painter = _textPainter(text, alpha);
    canvas.save();
    canvas.translate(0, -_Curves.easeOut(t) * _rise);
    canvas.scale(scaleIn);
    canvas.translate(-painter.width / 2, -painter.height / 2);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  TextPainter _textPainter(String value, double alpha) {
    final style = TextStyle(
      color: color.withOpacity(alpha.clamp(0.0, 1.0)),
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
      shadows: const [
        Shadow(color: Color(0xDD000000), blurRadius: 4, offset: Offset(1.5, 1.5)),
        Shadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 2)),
      ],
    );
    final tp = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }
}

/// Access to the ease-out-back curve used for the pop-in.
class _Curves {
  static double easeOut(double t) =>
      t >= 1 ? 1 : 1 - math.pow(2, -10 * t).toDouble();

  static double easeIn(double t) => t * t;

  static double easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }
}
