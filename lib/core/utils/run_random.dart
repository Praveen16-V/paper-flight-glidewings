/// Stable deterministic random streams for one gameplay run.
///
/// A named stream isolates a system's draws from every other system. Adding a
/// cosmetic coin wobble therefore cannot silently change tomorrow's Daily
/// obstacle sequence. The small xorshift generator is intentionally owned by
/// the app instead of delegating to a platform/library RNG implementation.
class RunRandom {
  RunRandom(this.seed);

  /// Public run seed stored in a replay descriptor / daily leaderboard context.
  final int seed;

  final Map<String, RunRandomStream> _streams = {};

  RunRandomStream stream(String namespace) =>
      _streams.putIfAbsent(namespace, () => RunRandomStream(_seedFor(namespace)));

  /// Produces an independent deterministic seed for a pooled entity. Entity
  /// seeds are drawn only from the named stream, preserving the parent layout
  /// stream even when component internals gain new random visual details.
  int nextEntitySeed(String namespace) => stream(namespace).nextInt(0x7fffffff);

  int _seedFor(String namespace) => _mix(seed, _stableHash(namespace));

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static int _mix(int left, int right) {
    var mixed = (left ^ right ^ 0x9e3779b9) & 0x7fffffff;
    mixed ^= mixed << 13;
    mixed ^= mixed >> 17;
    mixed ^= mixed << 5;
    mixed &= 0x7fffffff;
    return mixed == 0 ? 0x6d2b79f5 & 0x7fffffff : mixed;
  }
}

/// A deterministic xorshift32 stream. Methods mirror the subset of
/// `math.Random` used by gameplay spawners/components.
class RunRandomStream {
  RunRandomStream(int seed) : _state = _normalizeSeed(seed);

  int _state;

  static int _normalizeSeed(int seed) {
    final normalized = seed & 0x7fffffff;
    return normalized == 0 ? 0x6d2b79f5 & 0x7fffffff : normalized;
  }

  int _nextUint31() {
    var value = _state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    _state = value & 0x7fffffff;
    if (_state == 0) _state = 0x6d2b79f5 & 0x7fffffff;
    return _state;
  }

  double nextDouble() => _nextUint31() / 0x80000000;

  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be greater than zero');
    }
    return _nextUint31() % max;
  }

  bool nextBool() => (_nextUint31() & 1) == 1;

  double nextRange(double min, double max) =>
      min + nextDouble() * (max - min);
}

/// Minimal replay identity suitable for debugging a seed report or later replay
/// UI. It purposefully contains no player data or device-specific state.
class RunReplayDescriptor {
  const RunReplayDescriptor({
    required this.seed,
    required this.algorithmVersion,
  });

  final int seed;
  final int algorithmVersion;

  String get stableId => 'r$algorithmVersion-$seed';
}
