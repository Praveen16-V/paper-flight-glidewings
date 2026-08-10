import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/game/components/effects/thermal_column_component.dart';

void main() {
  group('ThermalColumnComponent', () {
    ThermalColumnComponent makeColumn() {
      final column = ThermalColumnComponent(laneIndex: 1, particleSeed: 7);
      column.activate(centerX: 195, radius: 40, lift: 120);
      // Reach the configured lift target without needing a mounted Flame game.
      column.update(0.25);
      return column;
    }

    test('applies lift smoothly inside a local column only', () {
      final column = makeColumn();
      final core = Vector2(195, GameConfig.designHeight * .56);
      final edge = Vector2(235, GameConfig.designHeight * .56);
      final outside = Vector2(250, GameConfig.designHeight * .56);

      expect(column.influenceAt(core), closeTo(1.0, 0.0001));
      expect(column.liftAt(core), greaterThan(0));
      expect(column.influenceAt(edge), 0.0);
      expect(column.liftAt(outside), 0.0);
    });

    test('a complete consistent orbit earns a temporary lift multiplier', () {
      final column = makeColumn();
      final centerY =
          GameConfig.designHeight * GameConfig.thermalColumnCoreYFraction;
      var completed = false;

      // A little more than one turn protects this expectation from harmless
      // floating-point loss at exactly 2π.
      for (var i = 0; i <= 52; i++) {
        final theta = (i / 48) * math.pi * 2;
        final position = Vector2(
          column.centerX +
              column.radius *
                  GameConfig.thermalSurfOrbitHorizontalRadiusMultiplier *
                  .42 *
                  math.cos(theta),
          centerY +
              GameConfig.thermalSurfOrbitVerticalRadius * .42 * math.sin(theta),
        );
        final update = column.trackPilot(position, 1 / 60);
        completed = completed || update.completedOrbit;
      }

      expect(completed, isTrue);
      final active = column.trackPilot(
        Vector2(
          column.centerX + column.radius * .1,
          centerY,
        ),
        1 / 60,
      );
      expect(active.bonusActive, isTrue);
      expect(active.liftMultiplier,
          closeTo(GameConfig.thermalSurfLiftMultiplier, 0.0001));
    });
  });
}
