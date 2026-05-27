import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/features/indices/data/indices_api_client.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';
import 'package:rico_investidor/models/asset_item.dart';

class IndicesRepository {
  IndicesRepository({IndicesApiClient? api}) : _api = api ?? IndicesApiClient();

  final IndicesApiClient _api;
  final _listCache = SessionCache<List<IndexQuoteDto>>(ttl: const Duration(minutes: 5));
  final Map<String, SessionCache<IndexDetailDto>> _detailCache = {};

  SessionCache<IndexDetailDto> _cacheFor(String symbol) {
    return _detailCache.putIfAbsent(
      normalizeIndexSymbol(symbol),
      () => SessionCache<IndexDetailDto>(ttl: const Duration(minutes: 10)),
    );
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

  Future<IndexDetailDto> getDetail(String symbol, {int historyLimit = 252}) async {
    final normalized = normalizeIndexSymbol(symbol);
    final cache = _cacheFor(normalized);
    final cached = cache.get();
    if (cached != null) return cached;

    final detail = await _api.getDetail(normalized);
    if (detail.history.length < historyLimit) {
      try {
        final history = await _api.getHistory(normalized, limit: historyLimit);
        final enriched = IndexDetailDto(quote: detail.quote, history: history.history);
        cache.set(enriched);
        return enriched;
      } catch (_) {}
    }

    cache.set(detail);
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
