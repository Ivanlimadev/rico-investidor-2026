import 'package:rico_investidor/features/fii/data/fii_api_client.dart';
import 'package:rico_investidor/features/fii/utils/fii_related.dart';
import 'package:rico_investidor/features/fii/utils/fii_screener_presets.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class FiiRepository {
  FiiRepository({FiiApiClient? api}) : _api = api ?? FiiApiClient();

  final FiiApiClient _api;

  List<FiiSummary>? _catalog;
  int? _totalCount;
  final Map<String, FiiDetail> _detailCache = {};

  Future<int> totalCount() async {
    if (_totalCount != null) return _totalCount!;
    try {
      final response = await _api.countFiis();
      _totalCount = response.total;
      return response.total;
    } catch (_) {
      final catalog = await loadCatalog();
      _totalCount = catalog.length;
      return catalog.length;
    }
  }

  Future<List<FiiSummary>> loadCatalog() async {
    if (_catalog != null) return _catalog!;

    final items = <FiiSummary>[];
    var offset = 0;
    const pageSize = 500;

    while (true) {
      final page = await _api.listFiis(limit: pageSize, offset: offset);
      items.addAll(page.fiis);
      offset += page.count;
      if (offset >= page.total || page.count == 0) break;
    }

    _catalog = items;
    _totalCount = items.length;
    return items;
  }

  Future<List<FiiSummary>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) {
      final catalog = await loadCatalog();
      return catalog.take(limit).toList();
    }

    try {
      final response = await _api.searchFiis(q, limit: limit);
      return response.fiis;
    } catch (_) {
      final catalog = await loadCatalog();
      final lower = q.toLowerCase();
      return catalog
          .where(
            (f) =>
                f.ticker.toLowerCase().contains(lower) ||
                f.name.toLowerCase().contains(lower),
          )
          .take(limit)
          .toList();
    }
  }

  Future<FiiDetail> getDetail(String ticker) async {
    final normalized = normalizeFiiTicker(ticker);
    final cached = _detailCache[normalized];
    if (cached != null) return cached;

    final detail = await _api.getFii(normalized);
    _detailCache[normalized] = detail;
    return detail;
  }

  Future<FiiDistributions> getDistributions(String ticker, {int years = 5}) {
    return _api.getDistributions(ticker, years: years);
  }

  Future<FiiHistoryResponse> getHistory(String ticker, {int limit = 24}) {
    return _api.getHistory(ticker, limit: limit);
  }

  Future<FiiCandlesResponse> getCandles(
    String ticker, {
    int limit = 252,
    String? start,
    String? end,
  }) {
    return _api.getCandles(ticker, limit: limit, start: start, end: end);
  }

  Future<FiiTenantsResponse> getTenants(String ticker) {
    return _api.getTenants(ticker);
  }

  Future<FiiScreenerResponse> screener(Map<String, String> params) {
    return _api.screener(params);
  }

  Future<List<FiiScreenerItem>> featuredFiis() async {
    try {
      final response = await screener(fiiFeaturedScreenerParams);
      if (response.data.isNotEmpty) return response.data;
    } catch (_) {}
    return featuredFiisOfflineFallback;
  }

  Future<List<FiiScreenerItem>> relatedFiis(FiiDetail detail, {int limit = relatedFiisLimit}) async {
    final candidates = <FiiScreenerItem>[];
    final seen = <String>{};

    void addItems(Iterable<FiiScreenerItem> items) {
      for (final item in items) {
        if (seen.add(item.ticker)) candidates.add(item);
      }
    }

    Future<void> tryScreener(Map<String, String> params) async {
      try {
        final response = await screener({...params, 'limit': '40'});
        addItems(response.data);
      } catch (_) {}
    }

    if (detail.segment != null && detail.fundType != null) {
      await tryScreener({'segment': detail.segment!, 'fund_type': detail.fundType!});
    }
    if (candidates.length < limit * 2 && detail.segment != null) {
      await tryScreener({'segment': detail.segment!});
    }
    if (candidates.length < limit * 2 && detail.fundType != null) {
      await tryScreener({'fund_type': detail.fundType!});
    }

    var picked = pickRelatedFiis(detail: detail, candidates: candidates, limit: limit);
    if (picked.length >= limit) return picked;

    try {
      final catalog = await loadCatalog();
      final screenerLike = catalog.map(
        (s) => FiiScreenerItem(
          ticker: s.ticker,
          name: s.name,
          segment: s.segment,
          managementType: s.managementType,
        ),
      );
      addItems(screenerLike);
      picked = pickRelatedFiis(detail: detail, candidates: candidates, limit: limit);
    } catch (_) {}

    if (picked.isNotEmpty) return picked;

    try {
      final fallback = await screener({'limit': '40', 'sort': 'dividend_yield_ttm', 'order': 'desc'});
      return pickRelatedFiis(detail: detail, candidates: fallback.data, limit: limit);
    } catch (_) {
      return picked;
    }
  }

  Future<void> refreshPortfolioFiiPrices(PortfolioState portfolio) async {
    for (final holding in portfolio.holdings) {
      if (!isFiiTicker(holding.symbol)) continue;
      try {
        final detail = await getDetail(holding.symbol);
        if (detail.closePrice != null && detail.closePrice! > 0) {
          final index = portfolio.holdings.indexWhere((h) => h.symbol == holding.symbol);
          if (index >= 0) {
            portfolio.holdings[index] = portfolio.holdings[index].copyWith(
              currentPrice: detail.closePrice,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<AssetItem?> resolveAsset(String symbol) async {
    if (!isFiiTicker(symbol)) return null;

    try {
      final detail = await getDetail(symbol);
      return AssetItem(
        symbol: detail.ticker,
        name: detail.name,
        category: MarketCategory.fiis,
        price: detail.closePrice ?? 0,
        changePercent: 0,
      );
    } catch (_) {
      return null;
    }
  }

  AssetItem summaryToAsset(FiiSummary summary) {
    return AssetItem(
      symbol: summary.ticker,
      name: summary.name,
      category: MarketCategory.fiis,
      price: 0,
      changePercent: 0,
    );
  }

  void invalidate() {
    _catalog = null;
    _totalCount = null;
    _detailCache.clear();
  }
}

final fiiRepository = FiiRepository();
