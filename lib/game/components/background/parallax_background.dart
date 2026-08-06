import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Alignment, LinearGradient;

import '../../../core/constants/game_config.dart';
import '../../../core/enums/game_enums.dart';

/// Three-layer parallax background that scrolls downward at different speeds.
///
/// Layer speeds (fraction of world scroll speed):
///   Far (sky):   0.15 — almost stationary, creates depth
///   Mid (clouds): 0.35
///   Near (city):  0.70 — nearly keeps pace with obstacles
///
/// Each layer tiles vertically — when the tile scrolls past the bottom it
/// wraps back to the top to create seamless looping.
class ParallaxBackground extends Component with HasGameRef {
  final List<_BgLayer> _layers = [];

  // Current biome colours — transitions smoothly on biome change.
  Color _skyTop = const Color(0xFF1A2744);
  Color _skyBottom = const Color(0xFF2E3D66);

  @override
  Future<void> onLoad() async {
    _layers.addAll([
      _BgLayer(speedFraction: 0.15, yOffset: 0),
      _BgLayer(speedFraction: 0.35, yOffset: 0),
      _BgLayer(speedFraction: 0.70, yOffset: 0),
    ]);
    await super.onLoad();
  }

  @override
  void update(double dt) {
    final scrollSpeed = (gameRef as dynamic).scrollSpeed as double;
    for (final layer in _layers) {
      layer.yOffset += scrollSpeed * layer.speedFraction * dt;
      // Tile wrap at designHeight.
      if (layer.yOffset >= GameConfig.designHeight) {
        layer.yOffset -= GameConfig.designHeight;
      }
    }
  }

  void transitionToBiome(Biome biome) {
    switch (biome) {
      case Biome.backyard:
        _skyTop = const Color(0xFF4FC3F7);
        _skyBottom = const Color(0xFF81D4FA);
      case Biome.city:
        _skyTop = const Color(0xFF1A2744);
        _skyBottom = const Color(0xFF2E3D66);
      case Biome.storm:
        _skyTop = const Color(0xFF263238);
        _skyBottom = const Color(0xFF37474F);
      case Biome.mountain:
        _skyTop = const Color(0xFF1B5E20);
        _skyBottom = const Color(0xFF2E7D32);
      case Biome.night:
        _skyTop = const Color(0xFF0D0D1A);
        _skyBottom = const Color(0xFF1A1F3A);
      case Biome.atmosphere:
        _skyTop = const Color(0xFF1A0033);
        _skyBottom = const Color(0xFF0D001A);
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

    // Draw each parallax layer.
    for (int i = 0; i < _layers.length; i++) {
      _drawLayer(canvas, i, _layers[i].yOffset);
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
    // Stars / distant clouds
    final paint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.fill;
    const stars = [
      (50.0, 80.0), (120.0, 40.0), (200.0, 120.0), (310.0, 60.0),
      (80.0, 200.0), (250.0, 180.0), (340.0, 150.0), (160.0, 300.0),
      (30.0, 350.0), (290.0, 320.0),
    ];
    for (final (x, y) in stars) {
      final dy = (y + yOffset) % GameConfig.designHeight;
      canvas.drawCircle(Offset(x, dy), 2, paint);
    }
  }

  void _drawMidLayer(Canvas canvas, double yOffset) {
    // Soft cloud shapes
    final paint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.fill;
    const clouds = [
      (60.0, 150.0, 80.0, 30.0),
      (220.0, 260.0, 100.0, 35.0),
      (330.0, 420.0, 70.0, 25.0),
      (100.0, 550.0, 90.0, 32.0),
      (260.0, 700.0, 75.0, 28.0),
    ];
    for (final (x, y, w, h) in clouds) {
      final dy = (y + yOffset) % GameConfig.designHeight;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, dy), width: w, height: h), paint);
    }
  }

  void _drawNearLayer(Canvas canvas, double yOffset) {
    // City silhouette — simple rectangular skyline
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
    for (final (x, y, w, h) in buildings) {
      final dy = (y + yOffset) % GameConfig.designHeight;
      canvas.drawRect(Rect.fromLTWH(x, dy, w, h), paint);
    }
  }
}

class _BgLayer {
  _BgLayer({required this.speedFraction, required this.yOffset});
  final double speedFraction;
  double yOffset;
}
