import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/dividends/models/dividend_calendar_models.dart';

class DividendCalendarRepository {
  DividendCalendarRepository({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;
  final Map<String, SessionCache<DividendCalendarResponse>> _cache = {};
  final Map<String, Future<DividendCalendarResponse>> _inFlight = {};

  String _cacheKey({
    required String market,
    required String sortBy,
    required int daysAhead,
  }) =>
      '$market:$sortBy:$daysAhead';

  SessionCache<DividendCalendarResponse> _cacheFor(String key) {
    return _cache.putIfAbsent(
      key,
      () => SessionCache<DividendCalendarResponse>(ttl: const Duration(minutes: 12)),
    );
  }

  Future<DividendCalendarResponse> fetchCalendar({
    required String market,
    String sortBy = 'payment',
    int daysAhead = 120,
  }) {
    final key = _cacheKey(market: market, sortBy: sortBy, daysAhead: daysAhead);
    final cached = _cacheFor(key).get();
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _client
        .getJson(
          '/v1/dividends/calendar',
          query: {
            'market': market,
            'sort_by': sortBy,
            'days_ahead': '$daysAhead',
          },
          fromJson: DividendCalendarResponse.fromJson,
          timeout: const Duration(seconds: 90),
        )
        .then((response) {
      _cacheFor(key).set(response);
      _inFlight.remove(key);
      return response;
    }).catchError((Object error, StackTrace stack) {
      _inFlight.remove(key);
      Error.throwWithStackTrace(error, stack);
    });
    _inFlight[key] = future;
    return future;
  }

  void invalidate() {
    _cache.clear();
    _inFlight.clear();
  }
}

final dividendCalendarRepository = DividendCalendarRepository();
