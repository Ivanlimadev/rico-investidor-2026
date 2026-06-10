import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/crypto/data/crypto_api_client.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioPriceRefreshResult {
  const PortfolioPriceRefreshResult({
    required this.updated,
    required this.total,
    this.usedCachedPrices = false,
  });

  final int updated;
  final int total;
  final bool usedCachedPrices;

  bool get isSuccess => updated > 0 || usedCachedPrices;
}

class PortfolioPriceService {
  PortfolioPriceService({
    GlobalMarketRepository? marketRepository,
    CryptoApiClient? cryptoApi,
  })  : _globalMarketRepository = marketRepository ?? globalMarketRepository,
        _cryptoApi = cryptoApi ?? CryptoApiClient();

  final GlobalMarketRepository _globalMarketRepository;
  final CryptoApiClient _cryptoApi;

  Future<PortfolioPriceRefreshResult> refreshAllDetailed(PortfolioState portfolio) async {
    if (portfolio.holdings.isEmpty) {
      return const PortfolioPriceRefreshResult(updated: 0, total: 0);
    }

    final total = portfolio.holdings.length;
    final hadCachedPrices = _holdingsWithPrice(portfolio) > 0;
    if (!await _ensureAuthReady()) {
      return PortfolioPriceRefreshResult(
        updated: 0,
        total: total,
        usedCachedPrices: hadCachedPrices,
      );
    }

    final usSymbols = <String>[];
    final cryptoSymbols = <String>[];
    for (final holding in portfolio.holdings) {
      final category = portfolio.categoryForHolding(holding);
      if (category == MarketCategory.cripto) {
        cryptoSymbols.add(holding.symbol);
      } else {
        usSymbols.add(holding.symbol);
      }
    }

    var updated = 0;
    if (usSymbols.isNotEmpty) {
      updated += await _refreshUsHoldings(portfolio, usSymbols);
    }
    if (cryptoSymbols.isNotEmpty) {
      updated += await _refreshCryptoHoldingsBatch(portfolio, cryptoSymbols);
    }

    return PortfolioPriceRefreshResult(
      updated: updated,
      total: total,
      usedCachedPrices: updated == 0 && hadCachedPrices,
    );
  }

  Future<bool> refreshAll(PortfolioState portfolio) async {
    final result = await refreshAllDetailed(portfolio);
    return result.isSuccess;
  }

  Future<bool> _ensureAuthReady() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await authSession.ensureAuthenticated();
      } catch (_) {}
      if (authSession.accessToken?.isNotEmpty == true) return true;
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
    return authSession.accessToken?.isNotEmpty == true;
  }

  int _holdingsWithPrice(PortfolioState portfolio) {
    return portfolio.holdings.where((holding) => holding.currentPrice > 0).length;
  }

  Future<int> _refreshUsHoldings(PortfolioState portfolio, List<String> symbols) async {
    final results = await Future.wait(
      symbols.map((symbol) => _refreshUsHolding(portfolio, symbol)),
    );
    return results.where((ok) => ok).length;
  }

  Future<bool> _refreshUsHolding(PortfolioState portfolio, String symbol) async {
    try {
      final quote = await _globalMarketRepository.resolvedQuoteForPortfolio(symbol);
      return _patchHolding(
        portfolio,
        quote.symbol,
        price: quote.price,
        changePercent: quote.changePercent,
      );
    } catch (_) {
      return false;
    }
  }

  Future<int> _refreshCryptoHoldingsBatch(
    PortfolioState portfolio,
    List<String> symbols,
  ) async {
    try {
      final response = await _cryptoApi.getQuotesBatch(symbols);
      var updated = 0;
      for (final quote in response.items) {
        if (_patchHolding(
          portfolio,
          quote.symbol,
          price: quote.price,
          changePercent: quote.changePercent,
        )) {
          updated++;
        }
      }
      return updated;
    } catch (_) {
      return 0;
    }
  }

  bool _patchHolding(
    PortfolioState portfolio,
    String symbol, {
    required double price,
    required double changePercent,
  }) {
    final key = symbol.toUpperCase();
    for (var i = 0; i < portfolio.holdings.length; i++) {
      final holding = portfolio.holdings[i];
      if (holding.symbol.toUpperCase() != key || price <= 0) continue;
      final priceChanged = (holding.currentPrice - price).abs() > 0.0001;
      final changeChanged = (holding.changePercent - changePercent).abs() > 0.0001;
      if (!priceChanged && !changeChanged) return false;
      final category = portfolio.categoryForHolding(holding);
      portfolio.holdings[i] = holding.copyWith(
        currentPrice: price,
        changePercent: changePercent,
        currency: resolvedHoldingCurrency(holding, category: category),
      );
      return true;
    }
    return false;
  }
}
