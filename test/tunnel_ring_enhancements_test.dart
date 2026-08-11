import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/game/components/collectibles/tunnel_ring_component.dart';

void main() {
  group('tunnel ring enhancements', () {
    test('ring variants communicate their distinct gate behaviour', () {
      expect(TunnelRingVariant.standard.displayName, 'Ring Gate');
      expect(TunnelRingVariant.precision.displayName, 'Precision Ring');
      expect(TunnelRingVariant.drifting.displayName, 'Drift Ring');
      expect(
        GameConfig.tunnelRingPrecisionPerfectHalfWidth,
        lessThan(GameConfig.tunnelRingStandardPerfectHalfWidth),
      );
    });

    test('precision chain gates initialize their narrower, linked profile', () {
      final ring = TunnelRingComponent()
        ..activate(
          spawnPosition: Vector2(195, -60),
          variant: TunnelRingVariant.precision,
          chainId: 7,
          chainIndex: 1,
          chainLength: 3,
        );

      expect(ring.isActive, isTrue);
      expect(ring.isChained, isTrue);
      expect(ring.chainId, 7);
      expect(ring.chainIndex, 1);
      expect(ring.chainLength, 3);
      expect(
        ring.perfectClearHalfWidth,
        GameConfig.tunnelRingPrecisionPerfectHalfWidth,
      );
      expect(ring.size.x, lessThan(120));

      ring.deactivate();
      expect(ring.isActive, isFalse);
      expect(ring.isChained, isFalse);
    });

    test('chain tuning remains compact and reachable', () {
      expect(
        GameConfig.tunnelRingChainMaxLength,
        greaterThanOrEqualTo(GameConfig.tunnelRingChainMinLength),
      );
      expect(GameConfig.tunnelRingChainVerticalSpacing, greaterThan(0));
      expect(GameConfig.tunnelRingChainHorizontalStep, lessThanOrEqualTo(50));
      expect(GameConfig.tunnelRingChainCompletionCoinCount, greaterThan(0));
    });
  });
}
