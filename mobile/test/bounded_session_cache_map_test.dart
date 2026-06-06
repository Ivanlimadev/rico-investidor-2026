import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/cache/bounded_session_cache_map.dart';

void main() {
  test('evicts oldest entry when maxEntries is reached', () {
    final store = BoundedSessionCacheMap<String>(maxEntries: 2);

    store.cacheFor('a').set('A');
    store.cacheFor('b').set('B');
    store.cacheFor('c').set('C');

    expect(store.cacheFor('b').get(), 'B');
    expect(store.cacheFor('c').get(), 'C');
    expect(store.cacheFor('a').get(), isNull);
  });

  test('touch keeps recently used entry', () {
    final store = BoundedSessionCacheMap<String>(maxEntries: 2);

    store.cacheFor('a').set('A');
    store.cacheFor('b').set('B');
    store.cacheFor('a');
    store.cacheFor('c').set('C');

    expect(store.cacheFor('a').get(), 'A');
    expect(store.cacheFor('c').get(), 'C');
    expect(store.cacheFor('b').get(), isNull);
  });
}
