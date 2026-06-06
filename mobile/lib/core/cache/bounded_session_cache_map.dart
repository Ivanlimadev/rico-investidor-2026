import 'package:rico_investidor/core/cache/session_cache.dart';

/// Mapa LRU de [SessionCache] — evita crescimento ilimitado por símbolo.
class BoundedSessionCacheMap<T> {
  BoundedSessionCacheMap({
    this.maxEntries = 256,
    this.defaultTtl = const Duration(minutes: 10),
  });

  final int maxEntries;
  final Duration defaultTtl;

  final _entries = <String, SessionCache<T>>{};
  final _order = <String>[];

  SessionCache<T> cacheFor(String key, {Duration? ttl}) {
    final existing = _entries[key];
    if (existing != null) {
      _touch(key);
      return existing;
    }

    _evictIfNeeded();
    final cache = SessionCache<T>(ttl: ttl ?? defaultTtl);
    _entries[key] = cache;
    _order.add(key);
    return cache;
  }

  void remove(String key) {
    _entries.remove(key);
    _order.remove(key);
  }

  void clear() {
    _entries.clear();
    _order.clear();
  }

  void _touch(String key) {
    _order.remove(key);
    _order.add(key);
  }

  void _evictIfNeeded() {
    while (_order.length >= maxEntries) {
      final oldest = _order.removeAt(0);
      _entries.remove(oldest);
    }
  }
}
