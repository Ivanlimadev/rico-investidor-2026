import 'package:rico_investidor/core/cache/bounded_session_cache_map.dart';
import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/crypto/data/crypto_api_client.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/models/asset_item.dart';

class CryptoRepository {
  CryptoRepository({CryptoApiClient? api}) : _api = api ?? CryptoApiClient();

  final CryptoApiClient _api;
  final _listCache = SessionCache<List<CryptoQuoteDto>>(ttl: const Duration(minutes: 5));
  final _moversCache = SessionCache<CryptoMoversResponseDto>(ttl: const Duration(minutes: 5));
  final _heatmapCache = SessionCache<CryptoListResponseDto>(ttl: const Duration(minutes: 5));
  final _macroCache = SessionCache<CryptoMacroSnapshotDto>(ttl: const Duration(minutes: 30));
  final _profileCache = BoundedSessionCacheMap<CryptoInvestorProfileDto>();
  final _detailCache = BoundedSessionCacheMap<CryptoDetailDto>(defaultTtl: const Duration(minutes: 2));
  final Map<String, Future<CryptoDetailDto>> _detailInFlight = {};

  SessionCache<CryptoDetailDto> _cacheFor(String symbol) {
    return _detailCache.cacheFor(normalizeCryptoSymbol(symbol));
  }

  Future<List<AssetItem>> listFeaturedAssets() async {
    final quotes = await listFeatured();
    return quotes.map((quote) => quote.toAssetItem()).toList();
  }

  Future<List<CryptoQuoteDto>> listFeatured() async {
    final cached = _listCache.get();
    if (cached != null) return cached;

    final response = await _api.listFeatured();
    _listCache.set(response.items);
    return response.items;
  }

  SessionCache<CryptoInvestorProfileDto> _profileCacheFor(String symbol) {
    return _profileCache.cacheFor(normalizeCryptoSymbol(symbol));
  }

  Future<CryptoInvestorProfileDto> getProfile(String symbol) async {
    final normalized = normalizeCryptoSymbol(symbol);
    final cache = _profileCacheFor(normalized);
    final cached = cache.get();
    if (cached != null) return cached;

    await authSession.ensureAuthenticated();
    final profile = await _api.getProfile(normalized);
    cache.set(profile);
    return profile;
  }

  Future<CryptoDetailDto> getDetail(String symbol, {String chartPreset = '1m'}) {
    final normalized = normalizeCryptoSymbol(symbol);
    final key = '$normalized:$chartPreset';
    final cache = _cacheFor(normalized);
    final cached = cache.get();
    if (cached != null) return Future.value(cached);

    final inFlight = _detailInFlight[key];
    if (inFlight != null) return inFlight;

    final future = _loadDetail(normalized, chartPreset: chartPreset).then((detail) {
      cache.set(detail);
      _detailInFlight.remove(key);
      return detail;
    }).catchError((Object error, StackTrace stack) {
      _detailInFlight.remove(key);
      Error.throwWithStackTrace(error, stack);
    });
    _detailInFlight[key] = future;
    return future;
  }

  Future<CryptoDetailDto> _loadDetail(String normalized, {required String chartPreset}) async {
    await authSession.ensureAuthenticated();
    final profileFuture = getProfile(normalized);
    final candlesFuture = _api.getCandles(normalized, preset: chartPreset);
    final results = await Future.wait([profileFuture, candlesFuture]);

    final profile = results[0] as CryptoInvestorProfileDto;
    final candles = results[1] as CryptoCandlesResponseDto;
    return CryptoDetailDto(
      quote: profile.quote,
      profile: profile,
      candles: candles.candles,
      history: candles.candles
          .map((candle) => CryptoHistoryPointDto(date: candle.date, value: candle.close))
          .toList(),
    );
  }

  Future<CryptoCandlesResponseDto> getCandles(String symbol, {String preset = '1m'}) {
    return _api.getCandles(normalizeCryptoSymbol(symbol), preset: preset);
  }

  Future<CryptoExploreResponseDto> explore({
    String? search,
    String group = 'all',
    int page = 1,
    int limit = 30,
  }) {
    return _api.explore(search: search, group: group, page: page, limit: limit);
  }

  Future<List<CryptoQuoteDto>> searchQuotes(String query, {int limit = 8}) async {
    final response = await explore(search: query, limit: limit);
    return response.items;
  }

  Future<CryptoMoversResponseDto> getMovers({int limit = 5}) async {
    final cached = _moversCache.get();
    if (cached != null) return cached;

    await authSession.ensureAuthenticated();
    final response = await _api.getMovers(limit: limit);
    _moversCache.set(response);
    return response;
  }

  Future<CryptoListResponseDto> getHeatmap({int limit = 18}) async {
    final cached = _heatmapCache.get();
    if (cached != null) return cached;

    await authSession.ensureAuthenticated();
    final response = await _api.getHeatmap(limit: limit);
    _heatmapCache.set(response);
    return response;
  }

  Future<CryptoMacroSnapshotDto> getMacro() async {
    final cached = _macroCache.get();
    if (cached != null) return cached;

    await authSession.ensureAuthenticated();
    final response = await _api.getMacro();
    _macroCache.set(response);
    return response;
  }
}

final cryptoRepository = CryptoRepository();
