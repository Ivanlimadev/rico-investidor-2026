class SessionCache<T> {
  SessionCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  DateTime? _expiresAt;
  T? _value;

  T? get() {
    if (_value == null || _expiresAt == null) return null;
    if (DateTime.now().isAfter(_expiresAt!)) {
      clear();
      return null;
    }
    return _value;
  }

  void set(T value) {
    _value = value;
    _expiresAt = DateTime.now().add(ttl);
  }

  void clear() {
    _value = null;
    _expiresAt = null;
  }
}
