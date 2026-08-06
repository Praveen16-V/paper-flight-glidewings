import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Alignment, LinearGradient;

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';
import '../../paper_flight_game.dart';

/// Three-layer parallax background that scrolls downward at different speeds.
///
/// Layer speeds (fraction of world scroll speed) — GDD §12:
///   Far (sky):   0.15 — almost stationary, creates depth
///   Mid (clouds): 0.35
///   Near (city):  0.70 — nearly keeps pace with obstacles
///
/// Each layer tiles vertically — when the tile scrolls past the bottom it
/// wraps back to the top to create seamless looping.
class ParallaxBackground extends Component with HasGameRef<PaperFlightGame> {
  final List<_BgLayer> _layers = [];

  // Current biome colours — transitions smoothly on biome change.
  Color _skyTop = const Color(0xFF4FC3F7);
  Color _skyBottom = const Color(0xFF81D4FA);
  Color _targetTop = const Color(0xFF4FC3F7);
  Color _targetBottom = const Color(0xFF81D4FA);
  double _blend = 1.0;

  Biome _biome = Biome.backyard;

  @override
  Future<void> onLoad() async {
    _layers.addAll([
      _BgLayer(speedFraction: 0.15, yOffset: 0),
      _BgLayer(speedFraction: 0.35, yOffset: 0),
      _BgLayer(speedFraction: 0.70, yOffset: 0),
    ]);
    transitionToBiome(Biome.backyard);
    await super.onLoad();
  }

  @override
  void update(double dt) {
    if (gameRef.phase != GamePhase.playing &&
        gameRef.phase != GamePhase.paused) {
      // Still animate slowly on menus if ever shown; otherwise idle.
    }

    final scrollSpeed = gameRef.effectiveScrollSpeed > 0
        ? gameRef.effectiveScrollSpeed
        : gameRef.scrollSpeed;

    for (final layer in _layers) {
      layer.yOffset += scrollSpeed * layer.speedFraction * dt;
      if (layer.yOffset >= GameConfig.designHeight) {
        layer.yOffset -= GameConfig.designHeight;
      }
    }

    // Smooth colour blend on biome change.
    if (_blend < 1.0) {
      _blend = (_blend + dt * 0.6).clamp(0.0, 1.0);
      _skyTop = Color.lerp(_skyTop, _targetTop, _blend) ?? _targetTop;
      _skyBottom =
          Color.lerp(_skyBottom, _targetBottom, _blend) ?? _targetBottom;
    }
  }

  void transitionToBiome(Biome biome) {
    _biome = biome;
    _blend = 0.0;
    switch (biome) {
      case Biome.backyard:
        _targetTop = const Color(0xFF4FC3F7);
        _targetBottom = const Color(0xFF81D4FA);
      case Biome.city:
        _targetTop = const Color(0xFF1A2744);
        _targetBottom = const Color(0xFF2E3D66);
      case Biome.storm:
        _targetTop = const Color(0xFF263238);
        _targetBottom = const Color(0xFF37474F);
      case Biome.mountain:
        _targetTop = const Color(0xFF1565C0);
        _targetBottom = const Color(0xFF2E7D32);
      case Biome.night:
        _targetTop = const Color(0xFF0D0D1A);
        _targetBottom = const Color(0xFF1A1F3A);
      case Biome.atmosphere:
        _targetTop = const Color(0xFF1A0033);
        _targetBottom = const Color(0xFF0D001A);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = GameConfig.designWidth;
    final h = GameConfig.designHeight;

    // Gradient sky background.
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_skyTop, _skyBottom],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), gradientPaint);

    // Draw each parallax layer (two tiles for seamless wrap).
    for (int i = 0; i < _layers.length; i++) {
      final yOff = _layers[i].yOffset;
      _drawLayer(canvas, i, yOff);
      _drawLayer(canvas, i, yOff - GameConfig.designHeight);
    }
  }

  void _drawLayer(Canvas canvas, int layerIndex, double yOffset) {
    switch (layerIndex) {
      case 0:
        _drawFarLayer(canvas, yOffset);
      case 1:
        _drawMidLayer(canvas, yOffset);
      case 2:
        _drawNearLayer(canvas, yOffset);
    }
  }

  void _drawFarLayer(Canvas canvas, double yOffset) {
    final paint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.fill;

    // Stars more visible in night/atmosphere.
    final starAlpha = (_biome == Biome.night || _biome == Biome.atmosphere)
        ? 0.55
        : 0.2;
    final starPaint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, starAlpha)
      ..style = PaintingStyle.fill;

    const stars = [
      (50.0, 80.0),
      (120.0, 40.0),
      (200.0, 120.0),
      (310.0, 60.0),
      (80.0, 200.0),
      (250.0, 180.0),
      (340.0, 150.0),
      (160.0, 300.0),
      (30.0, 350.0),
      (290.0, 320.0),
      (180.0, 480.0),
      (70.0, 560.0),
      (300.0, 620.0),
      (140.0, 700.0),
      (260.0, 760.0),
    ];
    for (final (x, y) in stars) {
      final dy = y + yOffset;
      if (dy < -10 || dy > GameConfig.designHeight + 10) continue;
      canvas.drawCircle(Offset(x, dy), 2, starPaint);
    }

    // Soft sun/moon glow depending on biome.
    if (_biome == Biome.backyard) {
      final sunPaint = Paint()
        ..color = const Color(0x44FFF59D)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(Offset(300, 100 + yOffset * 0.1), 40, sunPaint);
    }
  }

  void _drawMidLayer(Canvas canvas, double yOffset) {
    final paint = Paint()
      ..color = _biome == Biome.storm
          ? const Color(0x33445566)
          : const Color(0x22FFFFFF)
      ..style = PaintingStyle.fill;
    const clouds = [
      (60.0, 150.0, 80.0, 30.0),
      (220.0, 260.0, 100.0, 35.0),
      (330.0, 420.0, 70.0, 25.0),
      (100.0, 550.0, 90.0, 32.0),
      (260.0, 700.0, 75.0, 28.0),
      (40.0, 40.0, 60.0, 22.0),
      (180.0, 800.0, 85.0, 30.0),
    ];
    for (final (x, y, cw, ch) in clouds) {
      final dy = y + yOffset;
      if (dy < -40 || dy > GameConfig.designHeight + 40) continue;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, dy), width: cw, height: ch),
        paint,
      );
    }
  }

  void _drawNearLayer(Canvas canvas, double yOffset) {
    // Biome-specific near scenery.
    switch (_biome) {
      case Biome.backyard:
      case Biome.mountain:
        _drawTrees(canvas, yOffset);
      case Biome.city:
      case Biome.storm:
      case Biome.night:
        _drawBuildings(canvas, yOffset);
      case Biome.atmosphere:
        _drawMeteors(canvas, yOffset);
    }
  }

  void _drawBuildings(Canvas canvas, double yOffset) {
    final paint = Paint()
      ..color = const Color(0xFF0D1B2A)
      ..style = PaintingStyle.fill;
    const buildings = [
      (0.0, 650.0, 60.0, 194.0),
      (55.0, 700.0, 45.0, 144.0),
      (95.0, 620.0, 55.0, 224.0),
      (145.0, 680.0, 40.0, 164.0),
      (180.0, 640.0, 70.0, 204.0),
      (245.0, 710.0, 50.0, 134.0),
      (290.0, 660.0, 60.0, 184.0),
      (345.0, 700.0, 45.0, 144.0),
    ];
    for (final (x, y, bw, bh) in buildings) {
      final dy = y + yOffset;
      if (dy + bh < 0 || dy > GameConfig.designHeight) continue;
      canvas.drawRect(Rect.fromLTWH(x, dy, bw, bh), paint);
    }
  }

  void _drawTrees(Canvas canvas, double yOffset) {
    final trunk = Paint()..color = const Color(0xFF5D4037);
    final foliage = Paint()..color = const Color(0xFF2E7D32);
    const trees = [
      (30.0, 700.0),
      (100.0, 740.0),
      (200.0, 680.0),
      (300.0, 720.0),
      (360.0, 760.0),
      (150.0, 400.0),
      (280.0, 450.0),
    ];
    for (final (x, y) in trees) {
      final dy = y + yOffset;
      if (dy < -80 || dy > GameConfig.designHeight + 20) continue;
      canvas.drawRect(Rect.fromLTWH(x - 4, dy, 8, 40), trunk);
      canvas.drawCircle(Offset(x, dy - 10), 22, foliage);
    }
  }

  void _drawMeteors(Canvas canvas, double yOffset) {
    final paint = Paint()
      ..color = const Color(0x88FF7043)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const meteors = [
      (40.0, 100.0, 20.0),
      (200.0, 300.0, 30.0),
      (320.0, 500.0, 18.0),
      (120.0, 650.0, 25.0),
    ];
    for (final (x, y, len) in meteors) {
      final dy = y + yOffset;
      canvas.drawLine(Offset(x, dy), Offset(x + len * 0.4, dy + len), paint);
    }
  }
}

class _BgLayer {
  _BgLayer({required this.speedFraction, required this.yOffset});
  final double speedFraction;
  double yOffset;
}
