import '../../core/utils/run_random.dart';

/// The deterministic decisions that define a replayable layout.
enum ReplayTraceKind {
  obstacleSpawn,
  collectibleSpawn,
  tunnelRingSpawn,
  powerUpSpawn,
}

/// Compact immutable trace token. Coordinates are quantized before recording so
/// harmless floating-point noise does not make two layout traces diverge.
class ReplayTraceEntry {
  const ReplayTraceEntry({
    required this.ordinal,
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.x10,
    required this.y10,
  });

  final int ordinal;
  final ReplayTraceKind kind;
  final int primary;
  final int secondary;
  final int x10;
  final int y10;
}

/// A bounded view of a run's deterministic layout, suitable for a support
/// report, a soak assertion, or a later full replay renderer.
class RunReplaySnapshot {
  const RunReplaySnapshot({
    required this.descriptor,
    required this.eventCount,
    required this.fingerprint,
    required this.recentEntries,
  });

  final RunReplayDescriptor descriptor;
  final int eventCount;
  final String fingerprint;
  final List<ReplayTraceEntry> recentEntries;

  bool matches(RunReplaySnapshot other) =>
      descriptor.seed == other.descriptor.seed &&
      descriptor.algorithmVersion == other.descriptor.algorithmVersion &&
      eventCount == other.eventCount &&
      fingerprint == other.fingerprint;
}

/// Bounded deterministic trace recorder for a single game run.
///
/// The fingerprint incorporates every recorded event, while [recentEntries]
/// remains capped. This gives soak tests a fixed memory footprint without
/// giving up the ability to detect a layout divergence after a long flight.
class RunReplayTrace {
  RunReplayTrace({
    required this.descriptor,
    this.maxEntries = 192,
  })  : assert(maxEntries > 0),
        _hash = _initialHash(descriptor);

  final RunReplayDescriptor descriptor;
  final int maxEntries;
  final List<ReplayTraceEntry> _recentEntries = <ReplayTraceEntry>[];
  int _writeCursor = 0;
  int _eventCount = 0;
  int _hash;

  int get eventCount => _eventCount;

  /// Records one deterministic decision. [primary]/[secondary] are stable enum
  /// indexes or other versioned tokens supplied by the owning spawner.
  void record(
    ReplayTraceKind kind, {
    required int primary,
    int secondary = 0,
    double x = 0,
    double y = 0,
  }) {
    final entry = ReplayTraceEntry(
      ordinal: _eventCount,
      kind: kind,
      primary: primary,
      secondary: secondary,
      x10: (x * 10).round(),
      y10: (y * 10).round(),
    );
    _eventCount++;
    _hash = _mixEntry(_hash, entry);

    if (_recentEntries.length < maxEntries) {
      _recentEntries.add(entry);
    } else {
      _recentEntries[_writeCursor] = entry;
      _writeCursor = (_writeCursor + 1) % maxEntries;
    }
  }

  RunReplaySnapshot snapshot() {
    final orderedRecent = _recentEntries.length < maxEntries || _writeCursor == 0
        ? List<ReplayTraceEntry>.unmodifiable(_recentEntries)
        : List<ReplayTraceEntry>.unmodifiable([
            ..._recentEntries.sublist(_writeCursor),
            ..._recentEntries.sublist(0, _writeCursor),
          ]);
    final fingerprint =
        '${descriptor.stableId}-${_hash.toRadixString(16).padLeft(8, '0')}';
    return RunReplaySnapshot(
      descriptor: descriptor,
      eventCount: _eventCount,
      fingerprint: fingerprint,
      recentEntries: orderedRecent,
    );
  }

  static int stableToken(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static int _initialHash(RunReplayDescriptor descriptor) =>
      _mix(descriptor.seed, descriptor.algorithmVersion);

  static int _mixEntry(int previous, ReplayTraceEntry entry) {
    var hash = _mix(previous, entry.kind.index);
    hash = _mix(hash, entry.primary);
    hash = _mix(hash, entry.secondary);
    hash = _mix(hash, entry.x10);
    return _mix(hash, entry.y10);
  }

  static int _mix(int left, int right) {
    var value = (left ^ right ^ 0x9e3779b9) & 0x7fffffff;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value & 0x7fffffff;
  }
}

/// Pure helpers used by replay-driven soak tests and support tooling.
class ReplaySoakValidator {
  const ReplaySoakValidator._();

  static bool matches(RunReplaySnapshot expected, RunReplaySnapshot actual) =>
      expected.matches(actual);

  static bool staysBounded(RunReplaySnapshot snapshot, int maxEntries) =>
      snapshot.recentEntries.length <= maxEntries;
}
