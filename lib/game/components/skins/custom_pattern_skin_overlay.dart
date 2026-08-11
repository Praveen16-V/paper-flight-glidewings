import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// Decodes a player-imported base64 pattern and layers it over Custom Craft.
/// The image is loaded once on equip; invalid/imported-but-unsupported bytes
/// simply leave the procedural palette visible rather than breaking a flight.
class CustomPatternSkinOverlay extends PositionComponent {
  CustomPatternSkinOverlay({
    required this.patternBase64,
    required Vector2 planeSize,
  }) : super(
          size: planeSize,
          position: Vector2.zero(),
          anchor: Anchor.topLeft,
        );

  final String patternBase64;

  @override
  Future<void> onLoad() async {
    if (patternBase64.isEmpty) {
      await super.onLoad();
      return;
    }

    try {
      final bytes = base64Decode(patternBase64);
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 96,
        targetHeight: 64,
      );
      final frame = await codec.getNextFrame();
      final sprite = Sprite(frame.image);
      final overlay = SpriteComponent(
        sprite: sprite,
        size: size.clone(),
        position: size / 2,
        anchor: Anchor.center,
      )..angle = -math.pi / 2;
      // The imported pattern is positioned in the same local orientation as
      // the plane silhouette, so a workshop preview matches in-flight output.
      add(overlay);
    } catch (_) {
      // Keep the procedural Custom Craft skin usable when a pasted pattern is
      // malformed or unsupported on the current device.
    }
    await super.onLoad();
  }
}
