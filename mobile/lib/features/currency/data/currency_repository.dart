import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/features/currency/data/currency_api_client.dart';
import 'package:rico_investidor/features/currency/models/currency_models.dart';
import 'package:rico_investidor/models/asset_item.dart';

class CurrencyRepository {
  CurrencyRepository({CurrencyApiClient? api}) : _api = api ?? CurrencyApiClient();

  final CurrencyApiClient _api;
  final _listCache = SessionCache<List<CurrencyQuoteDto>>(ttl: const Duration(minutes: 5));
  final Map<String, SessionCache<CurrencyDetailDto>> _detailCache = {};

  SessionCache<CurrencyDetailDto> _cacheFor(String pair) {
    return _detailCache.putIfAbsent(
      normalizeCurrencyPair(pair),
      () => SessionCache<CurrencyDetailDto>(ttl: const Duration(minutes: 10)),
    );
  }

  Future<List<AssetItem>> listFeaturedAssets() async {
    final quotes = await listFeatured();
    return quotes.map((quote) => quote.toAssetItem()).toList();
  }

  Future<List<CurrencyQuoteDto>> listFeatured() async {
    final cached = _listCache.get();
    if (cached != null) return cached;

    final response = await _api.listFeatured();
    _listCache.set(response.items);
    return response.items;
  }

  Future<CurrencyDetailDto> getDetail(String pair, {int historyLimit = 252}) async {
    final normalized = normalizeCurrencyPair(pair);
    final cache = _cacheFor(normalized);
    final cached = cache.get();
    if (cached != null) return cached;

    final quoteFuture = _api.getRate(normalized);
    final historyFuture = _api.getHistory(normalized, limit: historyLimit);
    final results = await Future.wait([quoteFuture, historyFuture]);

    final detail = CurrencyDetailDto(
      quote: results[0] as CurrencyQuoteDto,
      history: (results[1] as CurrencyHistoryResponseDto).history,
    );
    cache.set(detail);
    return detail;
  }

  Future<CurrencyExploreResponseDto> explore({
    String? search,
    String group = 'all',
    int page = 1,
    int limit = 30,
  }) {
    return _api.explore(search: search, group: group, page: page, limit: limit);
  }

  Future<List<CurrencyQuoteDto>> searchQuotes(String query, {int limit = 8}) async {
    final response = await explore(search: query, limit: limit);
    return response.items;
  }
}

final currencyRepository = CurrencyRepository();
