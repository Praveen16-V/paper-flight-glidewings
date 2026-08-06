import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

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
    _drawThermals(canvas);
    _drawTurbulence(canvas);
    _drawBiomeMotes(canvas, biome);
    if (biome == Biome.storm) _drawStorm(canvas);
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

  void _drawThermals(Canvas canvas) {
    for (var lane = 0; lane < GameConfig.windLaneCount; lane++) {
      final wind = gameRef.windSystem.windAt(lane);
      if (wind.type != WindType.thermal) continue;
      final x = (lane + .5) * size.x / GameConfig.windLaneCount;
      final strength = wind.intensity;
      final glow = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color.fromRGBO(255, 183, 77, .03),
            Color.fromRGBO(255, 213, 79, .20 + strength * .14),
            Color.fromRGBO(255, 241, 180, .02),
          ],
        ).createShader(Rect.fromLTWH(x - 34, 40, 68, size.y - 80));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, size.y * .58), width: 62, height: size.y * .95), glow);
      final shimmer = Paint()..color = Color.fromRGBO(255, 235, 130, .32)..strokeWidth = 1.2;
      for (var i = 0; i < 6; i++) {
        final y = size.y - ((_time * (42 + strength * 65) + i * 127) % (size.y + 30));
        final wobble = sin(_time * 3 + i) * 12;
        canvas.drawCircle(Offset(x + wobble, y), 1.2 + (i % 2), shimmer);
      }
    }
  }

  void _drawTurbulence(Canvas canvas) {
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4;
    for (final pocket in gameRef.windSystem.turbulencePockets) {
      final x = pocket.normX * size.x;
      final r = pocket.radius * size.x;
      final pulse = .45 + sin(_time * 7 + x) * .15;
      ring.color = Color.fromRGBO(196, 228, 244, pulse.clamp(.12, .7).toDouble());
      for (var i = 0; i < 3; i++) {
        final rr = r * (.38 + i * .23) + sin(_time * 4 + i) * 3;
        canvas.drawArc(Rect.fromCircle(center: Offset(x, size.y * (.35 + i * .16)), radius: rr), _time * 2 + i, pi * 1.35, false, ring);
      }
    }
  }

  void _drawBiomeMotes(Canvas canvas, Biome biome) {
    if (biome == Biome.storm || biome == Biome.atmosphere) return;
    final color = biome == Biome.night ? const Color(0xFFB8FF9B) : const Color(0xFFF9F3D0);
    final paint = Paint()..color = color;
    for (final mote in _motes) {
      final alpha = biome == Biome.night ? .55 + sin(_time * 4 + mote.phase) * .35 : .24;
      paint.color = color.withOpacity(alpha.clamp(.08, .9).toDouble());
      if (biome == Biome.backyard) {
        // Dandelion seed: a soft seed head and trailing stem.
        canvas.drawCircle(Offset(mote.x, mote.y), mote.radius, paint);
        canvas.drawLine(Offset(mote.x, mote.y), Offset(mote.x - mote.direction * 7, mote.y + 5), paint..strokeWidth = .7);
      } else {
        canvas.drawCircle(Offset(mote.x, mote.y), mote.radius, paint);
      }
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
