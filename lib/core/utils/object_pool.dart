import 'dart:collection';

/// Immutable lifecycle counters for an [ObjectPool].
///
/// These diagnostics are intentionally cheap to read and never retained per
/// item; spawners can surface them in a debug HUD, performance capture, or
/// post-run telemetry without introducing allocations into acquire/release.
class ObjectPoolDiagnostics {
  const ObjectPoolDiagnostics({
    required this.label,
    required this.maxRetained,
    required this.available,
    required this.inUse,
    required this.created,
    required this.acquired,
    required this.reused,
    required this.released,
    required this.discarded,
    required this.rejectedReleases,
    required this.peakInUse,
  });

  final String label;
  final int maxRetained;
  final int available;
  final int inUse;
  final int created;
  final int acquired;
  final int reused;
  final int released;
  final int discarded;
  final int rejectedReleases;
  final int peakInUse;

  double get reuseRate => acquired == 0 ? 0.0 : reused / acquired;

  Map<String, Object> toMap() => {
        'label': label,
        'max_retained': maxRetained,
        'available': available,
        'in_use': inUse,
        'created': created,
        'acquired': acquired,
        'reused': reused,
        'released': released,
        'discarded': discarded,
        'rejected_releases': rejectedReleases,
        'peak_in_use': peakInUse,
      };
}

/// Generic identity-safe object pool for Flame components and other run-scoped
/// objects.
///
/// The pool tracks leased items, rejects duplicate releases, and bounds idle
/// retention with [maxRetained]. That makes accidental double callbacks visible
/// without allowing a long session to grow an unbounded cache.
class ObjectPool<T> {
  ObjectPool({
    required T Function() create,
    int initialSize = 8,
    int? maxRetained,
    String? label,
  })  : assert(initialSize >= 0),
        _create = create,
        label = label ?? 'ObjectPool<$T>',
        maxRetained = _resolveMaxRetained(initialSize, maxRetained) {
    warm(initialSize);
  }

  final T Function() _create;
  final String label;
  final int maxRetained;

  final List<T> _availableItems = <T>[];
  final Set<T> _availableIdentity = HashSet<T>.identity();
  final Set<T> _leasedIdentity = HashSet<T>.identity();

  int _created = 0;
  int _acquired = 0;
  int _reused = 0;
  int _released = 0;
  int _discarded = 0;
  int _rejectedReleases = 0;
  int _peakInUse = 0;

  static int _resolveMaxRetained(int initialSize, int? requested) {
    final defaultCap = initialSize == 0 ? 8 : initialSize * 2;
    final cap = requested ?? defaultCap;
    return cap < initialSize ? initialSize : cap;
  }

  /// Returns an item from the available stack or creates one when all are live.
  T acquire() {
    T item;
    if (_availableItems.isNotEmpty) {
      item = _availableItems.removeLast();
      _availableIdentity.remove(item);
      _reused++;
    } else {
      item = _create();
      _created++;
    }

    // A correctly managed pool never leases the same identity twice. Recover
    // safely if a caller corrupts lifecycle state instead of handing out an
    // already-live component a second time.
    if (!_leasedIdentity.add(item)) {
      item = _create();
      _created++;
      _leasedIdentity.add(item);
    }
    _acquired++;
    if (_leasedIdentity.length > _peakInUse) {
      _peakInUse = _leasedIdentity.length;
    }
    return item;
  }

  /// Returns [item] to the idle stack. Returns false when the item was not
  /// leased by this pool or when the configured retention cap discards it.
  bool release(T item) {
    if (!_leasedIdentity.remove(item)) {
      _rejectedReleases++;
      return false;
    }

    _released++;
    if (_availableItems.length >= maxRetained) {
      _discarded++;
      return false;
    }

    if (!_availableIdentity.add(item)) {
      _rejectedReleases++;
      return false;
    }
    _availableItems.add(item);
    return true;
  }

  /// Pre-creates enough idle objects to reach [targetAvailable], bounded by the
  /// configured cap. Useful for a deliberate warm-up rather than a first-run
  /// allocation spike.
  int warm(int targetAvailable) {
    final target = targetAvailable.clamp(0, maxRetained).toInt();
    var added = 0;
    while (_availableItems.length < target) {
      final item = _create();
      _created++;
      _availableItems.add(item);
      _availableIdentity.add(item);
      added++;
    }
    return added;
  }

  /// Drops excess idle instances and returns how many were trimmed. Leased
  /// instances are never touched, so it is safe to call during an active run.
  int trim({int targetAvailable = 0}) {
    final target = targetAvailable.clamp(0, maxRetained).toInt();
    var removed = 0;
    while (_availableItems.length > target) {
      final item = _availableItems.removeLast();
      _availableIdentity.remove(item);
      _discarded++;
      removed++;
    }
    return removed;
  }

  int get available => _availableItems.length;
  int get inUse => _leasedIdentity.length;

  ObjectPoolDiagnostics get diagnostics => ObjectPoolDiagnostics(
        label: label,
        maxRetained: maxRetained,
        available: available,
        inUse: inUse,
        created: _created,
        acquired: _acquired,
        reused: _reused,
        released: _released,
        discarded: _discarded,
        rejectedReleases: _rejectedReleases,
        peakInUse: _peakInUse,
      );
}
