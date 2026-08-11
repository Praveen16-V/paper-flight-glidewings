import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../paper_flight_game.dart';

/// Lightweight, procedural atmospheric layer. It intentionally uses no texture
/// assets: the air stays readable at every resolution and costs only a handful
/// of canvas primitives per frame.
class AtmosphereComponent extends PositionComponent with HasGameRef<PaperFlightGame> {
  AtmosphereComponent() : super(size: Vector2(GameConfig.designWidth, GameConfig.designHeight));

  final Random _random = Random(31);
  final List<_Mote> _motes = [];
  double _time = 0;
  double _lightning = 0;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 42; i++) {
      _motes.add(_newMote(initial: true));
    }
    await super.onLoad();
  }

  @override
  void update(double dt) {
    _time += dt;
    _lightning = max(0, _lightning - dt * 2.8);
    final biome = gameRef.biomeManager.currentBiome;
    if (biome == Biome.storm && _random.nextDouble() < dt * 0.12) _lightning = 1;

    for (var i = 0; i < _motes.length; i++) {
      final mote = _motes[i];
      final drift = biome == Biome.storm ? 210.0 : biome == Biome.atmosphere ? 95.0 : 38.0;
      mote.x += (mote.direction * drift + sin(_time * 1.7 + mote.phase) * 18) * dt;
      mote.y += mote.speed * dt;
      if (mote.x < -30 || mote.x > size.x + 30 || mote.y > size.y + 30) {
        _motes[i] = _newMote();
      }
    }
  }

  _Mote _newMote({bool initial = false}) => _Mote(
        x: _random.nextDouble() * size.x,
        y: initial ? _random.nextDouble() * size.y : -15,
        speed: 14 + _random.nextDouble() * 48,
        direction: _random.nextBool() ? 1 : -1,
        phase: _random.nextDouble() * pi * 2,
        radius: 1 + _random.nextDouble() * 2.2,
      );

  @override
  void render(Canvas canvas) {
    final biome = gameRef.biomeManager.currentBiome;
    _drawWindLanes(canvas);
    // Thermal lift is rendered by local ThermalColumnComponents rather than
    // as an ambiguous full-lane glow.
    _drawTurbulence(canvas);
    _drawBiomeMotes(canvas, biome);
    if (biome == Biome.storm) _drawStorm(canvas);
    if (biome == Biome.ocean) _drawOceanSpray(canvas);
    if (biome == Biome.night) _drawNightVignette(canvas);
    if (biome == Biome.atmosphere) _drawMeteors(canvas);
  }

  void _drawWindLanes(Canvas canvas) {
    for (var lane = 0; lane < GameConfig.windLaneCount; lane++) {
      final wind = gameRef.windSystem.windAt(lane);
      if (wind.type == WindType.thermal || wind.intensity < .18) continue;
      final left = lane * size.x / GameConfig.windLaneCount;
      final width = size.x / GameConfig.windLaneCount;
      final direction = wind.lateralForce == 0 ? 1.0 : wind.lateralForce.sign;
      final paint = Paint()
        ..color = Color.fromRGBO(225, 248, 255, (0.08 + wind.intensity * .17).clamp(0, .28).toDouble())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final y = ((_time * (38 + wind.intensity * 80) + i * 139 + lane * 47) % (size.y + 70)) - 35;
        final x = left + ((i * 61 + _time * direction * 55) % width);
        final length = 14 + wind.intensity * 30;
        canvas.drawLine(Offset(x, y), Offset(x + length * direction, y - 3), paint);
        // Tiny paper-confetti fleck that makes the direction more obvious.
        canvas.drawCircle(Offset(x - direction * 7, y + 4), 1.5 + wind.intensity, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      }
    }
  }

  void _drawTurbulence(Canvas canvas) {
    for (final pocket in gameRef.windSystem.turbulencePockets) {
      final x = pocket.normX * size.x;
      final radius = pocket.radius * size.x;
      final forceFraction =
          (pocket.lateralForce.abs() / GameConfig.maxWindForce)
              .clamp(0.0, 1.0)
              .toDouble();
      final direction = pocket.lateralForce == 0
          ? 1.0
          : pocket.lateralForce.sign;
      final life = pocket.lifeFraction;
      final pulse = .66 + sin(_time * pocket.shiftFrequency * pi + x) * .22;
      final alpha = (0.10 + pocket.intensity * 0.18) * pulse * life;
      final centerY = size.y * .54;

      // A translucent local weather cell makes the gameplay boundary legible
      // before the gust is felt. The cross-hatched swirls distinguish it from
      // an ordinary lane wind without relying only on colour.
      final field = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(128, 222, 234, alpha.clamp(0.0, .34).toDouble()),
            Color.fromRGBO(156, 39, 176, (alpha * .45).clamp(0.0, .16).toDouble()),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: Offset(x, centerY),
            width: radius * 3.1,
            height: size.y * .92,
          ),
        );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: radius * 3.1,
          height: size.y * .92,
        ),
        field,
      );

      final swirl = Paint()
        ..color = Color.fromRGBO(
          213,
          246,
          255,
          (0.30 + pocket.intensity * .40) * life,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round;
      final arrow = Paint()
        ..color = Color.fromRGBO(
          255,
          241,
          118,
          (0.38 + forceFraction * .45) * life,
        )
        ..style = PaintingStyle.fill;

      for (var i = 0; i < 4; i++) {
        final y = centerY - 118 + i * 78;
        final wave = sin(_time * 6.5 + i * 1.9) * 5;
        final arcRadius = radius * (.42 + i * .12) + wave;
        final start = direction > 0 ? 0.18 : pi + 0.18;
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(x, y),
            width: arcRadius * 2,
            height: arcRadius * 1.18,
          ),
          start,
          pi * 1.34,
          false,
          swirl,
        );

        // The chevron flips direction with the live physics force, so players
        // can read each rapid wind reversal rather than treating it as random.
        final progress = ((_time * (36 + pocket.shiftFrequency * 12) + i * 53) %
                (radius * 1.7)) /
            (radius * 1.7);
        final arrowX = x + (progress - .5) * radius * 1.7 * direction;
        final arrowPath = Path()
          ..moveTo(arrowX + direction * 5, y)
          ..lineTo(arrowX - direction * 3, y - 3.5)
          ..lineTo(arrowX - direction * 3, y + 3.5)
          ..close();
        canvas.drawPath(arrowPath, arrow);
      }

      final boundary = Paint()
        ..color = Color.fromRGBO(196, 228, 244, (.24 + alpha).clamp(0.0, .54).toDouble())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: radius * 2.15,
          height: size.y * .79,
        ),
        boundary,
      );
    }
  }

  /// Renders the world's background particulates as soft, glowing dust motes.
  ///
  /// Instead of hard little dots drifting straight down, each mote is a gentle
  /// radial-glow "light fleck" that bobs and drifts lazily with the breeze and
  /// twinkles in and out. It reads as clean atmospheric depth rather than
  /// clutter, and each biome tints it to match the scene.
  void _drawBiomeMotes(Canvas canvas, Biome biome) {
    if (biome == Biome.storm || biome == Biome.atmosphere) return;
    final color = biome == Biome.night
        ? const Color(0xFFB8FF9B)
        : biome == Biome.mountain
            ? const Color(0xFFE8F5E9)
            : biome == Biome.ocean
                ? const Color(0xFFB3E5FC)
                : const Color(0xFFFFF8E1);

    for (final mote in _motes) {
      // Gentle horizontal bob so the particles feel airy, not mechanical.
      final x = mote.x + cos(_time * 0.7 + mote.phase) * 8.0;
      final y = mote.y + sin(_time * 1.1 + mote.phase * 1.7) * mote.radius * 1.6;
      // Slow twinkle so the motes breathe rather than sit flat.
      final twinkle = 0.5 + 0.5 * sin(_time * 2.2 + mote.phase * 2.0);
      final alpha = (0.10 + 0.16 * twinkle).clamp(0.0, 1.0);
      final r = mote.radius * (0.85 + 0.3 * twinkle);

      // Soft outer glow (radial falloff) — the body of the mote.
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(alpha),
            color.withOpacity(alpha * 0.30),
            color.withOpacity(0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset(x, y), radius: r * 3.2),
        );
      canvas.drawCircle(Offset(x, y), r * 3.2, glow);

      // Bright core adds a crisp little sparkle at the centre.
      final core = Paint()
        ..color = color.withOpacity((alpha * 0.85).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), r * 0.55, core);
    }
  }

  void _drawOceanSpray(Canvas canvas) {
    final wave = Paint()
      ..color = const Color(0x66B3E5FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 7; i++) {
      final y = (i * 126.0 + _time * 34.0) % size.y;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.x * .25, y - 7, size.x * .5, y)
        ..quadraticBezierTo(size.x * .75, y + 7, size.x, y);
      canvas.drawPath(path, wave);
    }
    final foam = Paint()..color = const Color(0x99E1F5FE);
    for (var i = 0; i < 14; i++) {
      final x = (i * 53.0 + _time * 28.0) % size.x;
      final y = (i * 89.0 + _time * 46.0) % size.y;
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * .35, foam);
    }
  }

  void _drawStorm(Canvas canvas) {
    final rain = Paint()..color = const Color(0x88C5E7FF)..strokeWidth = 1.2;
    for (var i = 0; i < 46; i++) {
      final x = ((i * 47 + _time * 260) % (size.x + 70)) - 35;
      final y = ((_time * 520 + i * 83) % (size.y + 45)) - 20;
      canvas.drawLine(Offset(x, y), Offset(x - 12, y + 30), rain);
    }
    if (_lightning > 0) {
      canvas.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Color.fromRGBO(220, 238, 255, _lightning * .42));
    }
  }

  void _drawNightVignette(Canvas canvas) {
    canvas.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = const Color(0x66030A20));
  }

  void _drawMeteors(Canvas canvas) {
    final paint = Paint()..color = const Color(0xAAE1D7FF)..strokeWidth = 1.4;
    for (var i = 0; i < 5; i++) {
      final x = ((i * 109 + _time * 80) % (size.x + 80)) - 40;
      final y = (i * 151 + _time * 125) % size.y;
      canvas.drawLine(Offset(x, y), Offset(x - 20, y + 13), paint);
    }
  }
}

class _Mote {
  _Mote({required this.x, required this.y, required this.speed, required this.direction, required this.phase, required this.radius});
  double x;
  double y;
  final double speed;
  final double direction;
  final double phase;
  final double radius;
}
