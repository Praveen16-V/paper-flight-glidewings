import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/utils/run_random.dart';
import 'package:paper_flight/game/replay/run_replay_trace.dart';

void main() {
  const descriptor = RunReplayDescriptor(seed: 424242, algorithmVersion: 1);

  void recordLayout(RunReplayTrace trace, {int offset = 0}) {
    for (var i = 0; i < 10; i++) {
      trace.record(
        ReplayTraceKind.obstacleSpawn,
        primary: i % 4,
        secondary: i ~/ 2,
        x: 80 + i * 12 + offset,
        y: -80 - i * 30,
      );
    }
  }

  group('RunReplayTrace', () {
    test('identical seeded decisions produce the same fingerprint', () {
      final first = RunReplayTrace(descriptor: descriptor, maxEntries: 4);
      final second = RunReplayTrace(descriptor: descriptor, maxEntries: 4);
      recordLayout(first);
      recordLayout(second);

      final firstSnapshot = first.snapshot();
      final secondSnapshot = second.snapshot();
      expect(ReplaySoakValidator.matches(firstSnapshot, secondSnapshot), isTrue);
      expect(firstSnapshot.eventCount, 10);
      expect(firstSnapshot.recentEntries, hasLength(4));
      expect(
        firstSnapshot.recentEntries.map((entry) => entry.ordinal),
        orderedEquals([6, 7, 8, 9]),
      );
    });

    test('a changed layout decision is detected by the fingerprint', () {
      final expected = RunReplayTrace(descriptor: descriptor);
      final divergent = RunReplayTrace(descriptor: descriptor);
      recordLayout(expected);
      recordLayout(divergent, offset: 1);

      expect(
        ReplaySoakValidator.matches(expected.snapshot(), divergent.snapshot()),
        isFalse,
      );
    });

    test('long replay soak remains bounded while hashing every event', () {
      final trace = RunReplayTrace(descriptor: descriptor, maxEntries: 16);
      for (var i = 0; i < 2000; i++) {
        trace.record(
          ReplayTraceKind.collectibleSpawn,
          primary: i % 4,
          secondary: i % 26,
          x: i.toDouble(),
          y: -i.toDouble(),
        );
      }

      final snapshot = trace.snapshot();
      expect(snapshot.eventCount, 2000);
      expect(ReplaySoakValidator.staysBounded(snapshot, 16), isTrue);
      expect(snapshot.recentEntries, hasLength(16));
      expect(snapshot.fingerprint, contains(descriptor.stableId));
    });
  });
}
