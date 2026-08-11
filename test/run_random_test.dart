import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/utils/run_random.dart';

void main() {
  group('RunRandom', () {
    test('same seed and namespace reproduce an identical stream', () {
      final first = RunRandom(20260811).stream('obstacles');
      final second = RunRandom(20260811).stream('obstacles');

      final firstValues = List.generate(6, (_) => first.nextInt(100000));
      final secondValues = List.generate(6, (_) => second.nextInt(100000));

      expect(firstValues, orderedEquals(secondValues));
    });

    test('named streams remain isolated from cosmetic draws', () {
      final baseline = RunRandom(77);
      final withCosmetics = RunRandom(77);

      final expected = baseline.stream('layout').nextInt(1 << 20);
      final cosmetic = withCosmetics.stream('cosmetic');
      for (var i = 0; i < 12; i++) {
        cosmetic.nextDouble();
      }
      final actual = withCosmetics.stream('layout').nextInt(1 << 20);

      expect(actual, expected);
    });

    test('entity seeds and replay descriptors are stable and versioned', () {
      final first = RunRandom(9001);
      final second = RunRandom(9001);
      expect(
        first.nextEntitySeed('coin.standardCoin'),
        second.nextEntitySeed('coin.standardCoin'),
      );

      const descriptor = RunReplayDescriptor(seed: 9001, algorithmVersion: 1);
      expect(descriptor.stableId, 'r1-9001');
    });
  });
}
