/// Generic object pool for Flame components.
///
/// Usage:
///   final pool = ObjectPool<CoinComponent>(create: () => CoinComponent());
///   final coin = pool.acquire();
///   // ... use coin ...
///   pool.release(coin);
///
/// Prevents GC pressure from constant alloc/dealloc of recycled game objects.
class ObjectPool<T> {
  ObjectPool({
    required T Function() create,
    int initialSize = 8,
  }) : _create = create {
    for (int i = 0; i < initialSize; i++) {
      _pool.add(_create());
    }
  }

  final T Function() _create;
  final List<T> _pool = [];

  /// Returns an instance from the pool, creating one if pool is empty.
  T acquire() {
    if (_pool.isNotEmpty) return _pool.removeLast();
    return _create();
  }

  /// Returns [item] to the pool for later reuse.
  void release(T item) {
    _pool.add(item);
  }

  int get available => _pool.length;
}
