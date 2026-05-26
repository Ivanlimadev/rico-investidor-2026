import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';
import 'package:rico_investidor/features/quotes/models/stock_financials.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/quotes/models/stock_screener.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class QuoteRepository {
  QuoteRepository({QuoteApiClient? api}) : _api = api ?? QuoteApiClient();

  final QuoteApiClient _api;

  bool supportsCategory(MarketCategory category) {
    return switch (category) {
      MarketCategory.acoesBr || MarketCategory.bdr || MarketCategory.etf => true,
      _ => false,
    };
  }

  Future<List<AssetItem>> featuredStocks() async {
    final response = await _api.featured();
    return response.items.map((e) => e.toAssetItem()).toList();
  }

  Future<List<AssetItem>> search(String query, {int limit = 12}) async {
    final response = await _api.search(query, limit: limit);
    return response.items.map((e) => e.toAssetItem()).toList();
  }

  Future<List<AssetItem>> listByCategory(MarketCategory category, {int limit = 30}) async {
    if (!supportsCategory(category)) return const [];
    final response = await _api.listByCategory(category, limit: limit);
    return response.items.map((e) => e.toAssetItem()).toList();
  }

  Future<MarketQuoteDto> getQuote(String symbol) {
    return _api.getQuote(symbol);
  }

  Future<StockQuoteDetailDto> getStockDetail(String symbol) {
    return _api.getDetail(symbol);
  }

  Future<List<FiiCandleBar>> getStockCandles(String symbol, {FiiQuotePeriod? period}) async {
    final effective = period ?? FiiQuotePeriod.year1;
    final response = await _api.getCandles(
      symbol,
      range: rangeForQuotePeriod(effective),
      limit: limitForQuotePeriod(effective),
    );
    return response.candles;
  }

  Future<StockFinancialsDto> getStockFinancials(String symbol, {int limit = 8}) {
    return _api.getFinancials(symbol, limit: limit);
  }

  Future<StockScreenerResponseDto> screener(Map<String, String> query) {
    return _api.screener(query);
  }

  Future<StockCompareResponseDto> compareStocks(List<String> tickers) {
    return _api.compare(tickers);
  }

  Future<AssetItem?> resolveAsset(String symbol) async {
    if (isFiiTicker(symbol)) return null;
    try {
      final quote = await _api.getQuote(symbol);
      return quote.toAssetItem();
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshPortfolioStockPrices(PortfolioState portfolio) async {
    final symbols = portfolio.holdings
        .where((h) => !isFiiTicker(h.symbol))
        .map((h) => h.symbol)
        .toList();
    if (symbols.isEmpty) return;

    try {
      final response = await _api.batch(symbols);
      final bySymbol = {for (final item in response.items) item.symbol: item.toAssetItem()};
      for (var i = 0; i < portfolio.holdings.length; i++) {
        final holding = portfolio.holdings[i];
        final quote = bySymbol[holding.symbol];
        if (quote != null && quote.price > 0) {
          portfolio.holdings[i] = holding.copyWith(currentPrice: quote.price);
        }
      }
    } catch (_) {}
  }
}

final quoteRepository = QuoteRepository();
