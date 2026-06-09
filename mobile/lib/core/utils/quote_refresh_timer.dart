import 'dart:async';

typedef QuoteRefreshCallback = Future<void> Function();

/// Polling com backoff simples após falhas consecutivas.
class QuoteRefreshTimer {
  QuoteRefreshTimer({required this.onTick});

  final QuoteRefreshCallback onTick;

  Timer? _timer;
  int _failures = 0;
  int _baseSeconds = 60;
  int _minSeconds = 30;
  int _maxSeconds = 600;

  void start({
    required int refreshSeconds,
    required bool enabled,
    int minSeconds = 30,
    int maxSeconds = 600,
  }) {
    stop();
    if (!enabled) return;
    _minSeconds = minSeconds;
    _maxSeconds = maxSeconds;
    _baseSeconds = refreshSeconds.clamp(_minSeconds, _maxSeconds);
    _failures = 0;
    unawaited(_tick());
    _timer = Timer.periodic(Duration(seconds: _baseSeconds), (_) => _tick());
  }

  Future<void> _tick() async {
    try {
      await onTick();
      _failures = 0;
    } catch (_) {
      _failures++;
      if (_failures >= 3) {
        final slowed = (_baseSeconds * 2).clamp(_minSeconds, _maxSeconds);
        start(refreshSeconds: slowed, enabled: true, minSeconds: _minSeconds, maxSeconds: _maxSeconds);
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
