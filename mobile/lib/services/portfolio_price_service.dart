import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/crypto/data/crypto_api_client.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_api_client.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
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
    GlobalMarketApiClient? globalMarketApi,
    CryptoApiClient? cryptoApi,
  })  : _globalMarketApi = globalMarketApi ?? GlobalMarketApiClient(),
        _cryptoApi = cryptoApi ?? CryptoApiClient();

  final GlobalMarketApiClient _globalMarketApi;
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

    var updated = 0;
    for (final holding in portfolio.holdings) {
      final category = portfolio.categoryForHolding(holding);
      if (category == MarketCategory.cripto) {
        if (await _refreshCryptoHolding(portfolio, holding.symbol)) updated++;
      } else if (await _refreshUsHolding(portfolio, holding.symbol)) {
        updated++;
      }
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

  Future<bool> _refreshUsHolding(PortfolioState portfolio, String symbol) async {
    try {
      final quote = await _globalMarketApi.getQuote(symbol);
      return _patchHolding(
        portfolio,
        symbol,
        price: quote.price,
        changePercent: quote.changePercent,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _refreshCryptoHolding(PortfolioState portfolio, String symbol) async {
    try {
      final quote = await _cryptoApi.getQuote(symbol);
      return _patchHolding(
        portfolio,
        symbol,
        price: quote.price,
        changePercent: quote.changePercent,
      );
    } catch (_) {
      return false;
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
