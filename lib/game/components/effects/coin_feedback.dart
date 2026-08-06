import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/painting.dart';
import 'package:flame/components.dart';

import '../../paper_flight_game.dart';

/// Spawns a satisfying coin-pickup feedback at [position] on the [game]: a gold
/// sparkle burst plus a floating "+points" text that drifts up and fades out.
///
/// Both effects are short-lived and remove themselves, so they need no pooling.
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
}

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

class _Particle {
  _Particle({required this.dir, required this.size});
  final Vector2 pos = Vector2.zero();
  Vector2 dir;
  double size;
}

/// A "+points" label that pops in, floats upward, and fades out.
class FloatingScoreText extends PositionComponent {
  FloatingScoreText({required super.position, required this.text});

  final String text;

  double _elapsed = 0;
  static const double _life = 0.8; // seconds
  static const double _rise = 55.0; // px total

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
      color: Color.fromRGBO(255, 215, 0, alpha),
      fontSize: 18,
      fontWeight: FontWeight.w800,
      shadows: const [
        Shadow(color: Color(0xAA000000), blurRadius: 3, offset: Offset(1, 1)),
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
