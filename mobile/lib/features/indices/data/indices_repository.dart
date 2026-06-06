import 'package:rico_investidor/core/cache/bounded_session_cache_map.dart';
import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/features/indices/data/indices_api_client.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';
import 'package:rico_investidor/models/asset_item.dart';

class IndicesRepository {
  IndicesRepository({IndicesApiClient? api}) : _api = api ?? IndicesApiClient();

  final IndicesApiClient _api;
  final _listCache = SessionCache<List<IndexQuoteDto>>(ttl: const Duration(minutes: 5));
  final _detailCache = BoundedSessionCacheMap<IndexDetailDto>();
  final Map<String, Future<IndexDetailDto>> _detailInFlight = {};

  SessionCache<IndexDetailDto> _cacheFor(String symbol) {
    return _detailCache.cacheFor(normalizeIndexSymbol(symbol));
  }

  Future<List<AssetItem>> listFeaturedAssets() async {
    final quotes = await listFeatured();
    return quotes.map((quote) => quote.toAssetItem()).toList();
  }

  Future<List<IndexQuoteDto>> listFeatured() async {
    final cached = _listCache.get();
    if (cached != null) return cached;

    final response = await _api.listFeatured();
    _listCache.set(response.items);
    return response.items;
  }

  Future<IndexDetailDto> getDetail(String symbol, {int historyLimit = 252}) {
    final normalized = normalizeIndexSymbol(symbol);
    final key = '$normalized:$historyLimit';
    final cache = _cacheFor(normalized);
    final cached = cache.get();
    if (cached != null) return Future.value(cached);

    final inFlight = _detailInFlight[key];
    if (inFlight != null) return inFlight;

    final future = _loadDetail(normalized, historyLimit: historyLimit).then((detail) {
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

  Future<IndexDetailDto> _loadDetail(String normalized, {required int historyLimit}) async {
    final detail = await _api.getDetail(normalized);
    if (detail.history.length < historyLimit) {
      try {
        final history = await _api.getHistory(normalized, limit: historyLimit);
        return IndexDetailDto(quote: detail.quote, history: history.history);
      } catch (_) {}
    }
    return detail;
  }

  Future<IndexExploreResponseDto> explore({
    String? search,
    String group = 'all',
    int page = 1,
    int limit = 30,
  }) {
    return _api.explore(search: search, group: group, page: page, limit: limit);
  }

  Future<List<IndexQuoteDto>> searchIndices(String query, {int limit = 8}) async {
    final response = await explore(search: query, limit: limit);
    return response.items;
  }
}

final indicesRepository = IndicesRepository();
