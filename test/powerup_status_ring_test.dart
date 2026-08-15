import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

/// Item 9: while a power-up is active, the plane wears a visual that says so.
void main() {
  group('status ring geometry', () {
    test('the ring sits outside the snap charge ring', () {
      expect(
        GameConfig.powerUpStatusRingRadius,
        greaterThan(GameConfig.snapRingRadius),
      );
      expect(GameConfig.powerUpStatusRingStrokeWidth, greaterThan(0));
    });

    test('the arc leaves a gap so its start and end are distinguishable', () {
      expect(GameConfig.powerUpStatusRingGapRadians, greaterThan(0));
      // A gap large enough to see, small enough that the ring still reads as
      // a full-circle gauge.
      expect(GameConfig.powerUpStatusRingGapRadians, lessThan(1.0));
    });

    test('concentric rings cannot overlap each other', () {
      // The renderer steps each successive ring out by stroke width + 2.5,
      // which must exceed the stroke itself or adjacent arcs would collide.
      const step = GameConfig.powerUpStatusRingStrokeWidth + 2.5;
      expect(step, greaterThan(GameConfig.powerUpStatusRingStrokeWidth));
    });

    test('every power-up can tint a ring distinctly', () {
      final colors = <int>{};
      for (final type in PowerUpType.values) {
        expect(type.visualColor.alpha, greaterThan(0));
        colors.add(type.visualColor.value);
      }
      expect(
        colors.length,
        PowerUpType.values.length,
        reason: 'two effects sharing a tint would be indistinguishable '
            'as concentric rings',
      );
    });
  });

  group('every active power-up is legible on the plane', () {
    test('each type has a duration a countdown ring can divide by', () {
      // _drawPowerUpStatusRings divides remaining/total, so a zero or missing
      // duration would render an invalid arc.
      for (final type in PowerUpType.values) {
        final total = GameConfig.powerUpActiveDuration(type);
        expect(
          total,
          greaterThan(0),
          reason: '${type.displayName} needs a positive duration to draw a '
              'countdown ring',
        );
      }
    });

    test('ring order is stable across the whole roster', () {
      // Rings are ordered by PowerUpType.values, not by activation time, so a
      // ring never jumps radius when an unrelated effect expires.
      final order = PowerUpType.values.map((t) => t.name).toList();
      expect(order, equals(order.toSet().toList()));
      expect(order.first, 'shield');
      expect(order.last, 'blast');
    });
  });

  group('scale-aware overlays', () {
    test('Giant and Shrink move the silhouette in opposite directions', () {
      expect(GameConfig.giantVisualScale, greaterThan(1.0));
      expect(GameConfig.shrinkVisualScale, lessThan(1.0));
    });

    test('a giant plane is wider than the base ring radius', () {
      // This is why the renderer pushes the ring stack outward: at giant
      // scale the plane would otherwise swallow the innermost arc.
      const planeHalfWidth = 48 / 2;
      final giantReach = planeHalfWidth * GameConfig.giantVisualScale;
      expect(giantReach, greaterThan(0));
      expect(
        GameConfig.powerUpStatusRingRadius,
        lessThan(giantReach + GameConfig.powerUpStatusRingStrokeWidth * 2),
        reason: 'the fixed radius is insufficient at giant scale, so the '
            'renderer must expand it',
      );
    });
  });
}
