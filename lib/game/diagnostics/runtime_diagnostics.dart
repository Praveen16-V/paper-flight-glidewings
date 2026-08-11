import '../../core/utils/object_pool.dart';
import '../replay/run_replay_trace.dart';

/// Immutable diagnostic bundle sampled outside the game frame hot path.
///
/// It connects deterministic replay integrity, pool lifecycle health, active
/// entity counts, and adaptive difficulty into one post-run/paused view without
/// giving UI or analytics direct access to live mutable systems.
class RuntimeDiagnosticsSnapshot {
  const RuntimeDiagnosticsSnapshot({
    required this.runSeed,
    required this.replay,
    required this.pools,
    required this.activeObstacles,
    required this.activeCoins,
    required this.activeRings,
    required this.activePowerUps,
    required this.dynamicDifficulty,
  });

  final int runSeed;
  final RunReplaySnapshot replay;
  final List<ObjectPoolDiagnostics> pools;
  final int activeObstacles;
  final int activeCoins;
  final int activeRings;
  final int activePowerUps;
  final double dynamicDifficulty;

  int get poolCreated =>
      pools.fold(0, (total, diagnostics) => total + diagnostics.created);
  int get poolDiscarded =>
      pools.fold(0, (total, diagnostics) => total + diagnostics.discarded);
  int get poolRejectedReleases => pools.fold(
        0,
        (total, diagnostics) => total + diagnostics.rejectedReleases,
      );
  int get poolPeakInUse =>
      pools.fold(0, (total, diagnostics) => total + diagnostics.peakInUse);

  int get activeEntityCount =>
      activeObstacles + activeCoins + activeRings + activePowerUps;
}
