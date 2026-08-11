import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/utils/object_pool.dart';
import 'package:paper_flight/core/utils/run_random.dart';
import 'package:paper_flight/game/diagnostics/runtime_diagnostics.dart';
import 'package:paper_flight/game/replay/run_replay_trace.dart';

void main() {
  test('runtime diagnostics aggregate bounded replay and pool health', () {
    const descriptor = RunReplayDescriptor(seed: 12, algorithmVersion: 1);
    final trace = RunReplayTrace(descriptor: descriptor, maxEntries: 2)
      ..record(ReplayTraceKind.obstacleSpawn, primary: 1, x: 100, y: -80)
      ..record(ReplayTraceKind.collectibleSpawn, primary: 2, x: 110, y: -40)
      ..record(ReplayTraceKind.powerUpSpawn, primary: 3, x: 120, y: -50);
    final snapshot = RuntimeDiagnosticsSnapshot(
      runSeed: descriptor.seed,
      replay: trace.snapshot(),
      pools: const [
        ObjectPoolDiagnostics(
          label: 'obstacles',
          maxRetained: 6,
          available: 3,
          inUse: 2,
          created: 8,
          acquired: 14,
          reused: 10,
          released: 12,
          discarded: 2,
          rejectedReleases: 1,
          peakInUse: 5,
        ),
        ObjectPoolDiagnostics(
          label: 'coins',
          maxRetained: 48,
          available: 12,
          inUse: 4,
          created: 20,
          acquired: 32,
          reused: 28,
          released: 30,
          discarded: 1,
          rejectedReleases: 0,
          peakInUse: 9,
        ),
      ],
      activeObstacles: 2,
      activeCoins: 4,
      activeRings: 1,
      activePowerUps: 1,
      dynamicDifficulty: .47,
    );

    expect(snapshot.replay.eventCount, 3);
    expect(snapshot.replay.recentEntries, hasLength(2));
    expect(snapshot.poolCreated, 28);
    expect(snapshot.poolDiscarded, 3);
    expect(snapshot.poolRejectedReleases, 1);
    expect(snapshot.poolPeakInUse, 14);
    expect(snapshot.activeEntityCount, 8);
  });
}
