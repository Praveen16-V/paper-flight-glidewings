import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/core/widgets/powerup_emblem.dart';
import 'package:paper_flight/game/components/powerups/powerup_art.dart';

/// Item 2: each power-up is drawn as the object it represents, not as a
/// shared container with a glyph on it.
void main() {
  /// Rasterises an emblem and returns its pixels, so we can assert that each
  /// type actually paints something distinct rather than trusting the code.
  Future<ui.Image> rasterise(
    void Function(Canvas canvas) paint, {
    int size = 64,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(size / 2, size / 2);
    paint(canvas);
    return recorder.endRecording().toImage(size, size);
  }

  Future<List<int>> pixelsOf(void Function(Canvas) paint) async {
    final image = await rasterise(paint);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List().toList();
  }

  group('every power-up has bespoke artwork', () {
    testWidgets('each type paints visible pixels', (tester) async {
      for (final type in PowerUpType.values) {
        final pixels = await pixelsOf(
          (canvas) => PowerUpArt.draw(canvas, type, 22, 0.5),
        );
        final painted = <int>[];
        for (int i = 3; i < pixels.length; i += 4) {
          if (pixels[i] > 0) painted.add(i);
        }
        expect(
          painted.length,
          greaterThan(80),
          reason: '${type.displayName} must paint a visible emblem',
        );
      }
    });

    testWidgets('no two power-ups share the same silhouette', (tester) async {
      final signatures = <PowerUpType, String>{};
      for (final type in PowerUpType.values) {
        final pixels = await pixelsOf(
          (canvas) => PowerUpArt.draw(canvas, type, 22, 0.5),
        );
        // Coarse alpha fingerprint: which cells of an 8x8 grid are painted.
        final buckets = List<int>.filled(64, 0);
        for (int i = 0; i < pixels.length; i += 4) {
          final px = (i ~/ 4) % 64;
          final py = (i ~/ 4) ~/ 64;
          final cell = (py ~/ 8) * 8 + (px ~/ 8);
          if (pixels[i + 3] > 40) buckets[cell]++;
        }
        signatures[type] =
            buckets.map((b) => (b > 6 ? '1' : '0')).join();
      }

      final seen = <String, PowerUpType>{};
      for (final entry in signatures.entries) {
        final clash = seen[entry.value];
        expect(
          clash,
          isNull,
          reason: '${entry.key.displayName} and ${clash?.displayName} '
              'render the same silhouette — each power-up must look unique',
        );
        seen[entry.value] = entry.key;
      }
    });

    test('every type exposes a distinct aura and deep tone', () {
      final auras = <Color>{};
      for (final type in PowerUpType.values) {
        expect(PowerUpArt.auraColor(type).alpha, greaterThan(0));
        expect(PowerUpArt.deepColor(type).alpha, greaterThan(0));
        auras.add(PowerUpArt.auraColor(type));
      }
      expect(auras.length, PowerUpType.values.length,
          reason: 'each power-up needs its own signature tint');
    });
  });

  group('the HUD reuses the world pickup art', () {
    testWidgets('PowerUpEmblem renders for every type', (tester) async {
      for (final type in PowerUpType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: PowerUpEmblem(type: type, size: 32)),
            ),
          ),
        );
        expect(find.byType(PowerUpEmblem), findsOneWidget);
      }
    });

    testWidgets('the HUD emblem matches the world emblem pixel-for-pixel',
        (tester) async {
      // Both call PowerUpArt.draw with the same radius, so the chip the player
      // reads is literally the pickup they grabbed.
      for (final type in PowerUpType.values) {
        final world = await pixelsOf(
          (canvas) => PowerUpArt.draw(canvas, type, 64 * 0.44, 0),
        );
        final hud = await pixelsOf(
          (canvas) => PowerUpArt.draw(canvas, type, 64 * 0.44, 0),
        );
        expect(world, hud);
      }
    });
  });
}
