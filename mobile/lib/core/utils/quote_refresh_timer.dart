import 'dart:async';

typedef QuoteRefreshCallback = Future<void> Function();

/// Polling com backoff simples após falhas consecutivas.
class QuoteRefreshTimer {
  QuoteRefreshTimer({required this.onTick});

  final QuoteRefreshCallback onTick;

  Timer? _timer;
  int _failures = 0;
  int _baseSeconds = 60;

  void start({required int refreshSeconds, required bool enabled}) {
    stop();
    if (!enabled) return;
    _baseSeconds = refreshSeconds.clamp(30, 600);
    _failures = 0;
    _timer = Timer.periodic(Duration(seconds: _baseSeconds), (_) => _tick());
  }

  Future<void> _tick() async {
    try {
      await onTick();
      _failures = 0;
    } catch (_) {
      _failures++;
      if (_failures >= 3) {
        final slowed = (_baseSeconds * 2).clamp(60, 600);
        start(refreshSeconds: slowed, enabled: true);
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
