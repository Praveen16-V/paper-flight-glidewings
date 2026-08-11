import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/utils/object_pool.dart';

class _PooledItem {}

void main() {
  group('ObjectPool diagnostics and capacity', () {
    test('tracks reuse, peak leases, and capacity discards', () {
      var created = 0;
      final pool = ObjectPool<_PooledItem>(
        create: () {
          created++;
          return _PooledItem();
        },
        initialSize: 2,
        maxRetained: 2,
        label: 'test.pool',
      );

      expect(pool.available, 2);
      final first = pool.acquire();
      final second = pool.acquire();
      final third = pool.acquire();
      expect(created, 3);
      expect(pool.inUse, 3);

      expect(pool.release(first), isTrue);
      expect(pool.release(second), isTrue);
      expect(pool.release(third), isFalse); // retention cap reached

      final diagnostics = pool.diagnostics;
      expect(diagnostics.label, 'test.pool');
      expect(diagnostics.created, 3);
      expect(diagnostics.reused, 2);
      expect(diagnostics.peakInUse, 3);
      expect(diagnostics.available, 2);
      expect(diagnostics.inUse, 0);
      expect(diagnostics.discarded, 1);
    });

    test('rejects duplicate release and supports explicit trim/warm tuning', () {
      final pool = ObjectPool<_PooledItem>(
        create: _PooledItem.new,
        initialSize: 1,
        maxRetained: 3,
      );
      final item = pool.acquire();
      expect(pool.release(item), isTrue);
      expect(pool.release(item), isFalse);
      expect(pool.diagnostics.rejectedReleases, 1);

      expect(pool.warm(3), 2);
      expect(pool.available, 3);
      expect(pool.trim(targetAvailable: 1), 2);
      expect(pool.available, 1);
      expect(pool.diagnostics.discarded, 2);
    });
  });
}
