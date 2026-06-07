import 'package:rico_investidor/core/utils/dividend_payment_mappers.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/portfolio/utils/portfolio_dividend_mapper.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

/// Resultado da sincronização de proventos da carteira.
class PortfolioDividendSyncResult {
  const PortfolioDividendSyncResult({
    required this.completed,
    this.failedSymbols = const [],
  });

  final bool completed;
  final List<String> failedSymbols;

  bool totalFailureFor(int holdingsCount) =>
      holdingsCount > 0 && failedSymbols.length >= holdingsCount;
}

/// Sincroniza proventos reais da API com base nas posições da carteira (US + cripto).
class PortfolioDividendService {
  const PortfolioDividendService({
    required this.globalMarketRepository,
    this.lookbackYears = 5,
    this.dividendLimit = GlobalMarketRepository.extendedDividendLimit,
    this.holdingTimeout = const Duration(seconds: 20),
  });

  final GlobalMarketRepository globalMarketRepository;
  final int lookbackYears;
  final int dividendLimit;
  final Duration holdingTimeout;

  Future<PortfolioDividendSyncResult> syncPortfolioDividends(
    PortfolioState portfolio,
  ) async {
    if (portfolio.holdings.isEmpty) {
      portfolio.replaceDividends(const []);
      return const PortfolioDividendSyncResult(completed: true);
    }

    final cutoff = _cutoffDate();
    final failedSymbols = <String>[];
    final merged = <String, DividendPayment>{};

    await Future.wait(
      portfolio.holdings.map((holding) async {
        try {
          final batch = await _fetchForHolding(portfolio, holding, cutoff).timeout(holdingTimeout);
          for (final payment in batch) {
            merged[payment.id] = payment;
          }
        } catch (_) {
          failedSymbols.add(holding.symbol);
        }
      }),
    );

    final sorted = merged.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    portfolio.replaceDividends(sorted);

    return PortfolioDividendSyncResult(
      completed: true,
      failedSymbols: failedSymbols,
    );
  }

  DateTime _cutoffDate() {
    final now = DateTime.now();
    return DateTime(now.year - lookbackYears, now.month, now.day);
  }

  Future<List<DividendPayment>> _fetchForHolding(
    PortfolioState portfolio,
    PortfolioHolding holding,
    DateTime cutoff,
  ) async {
    final category = portfolio.categoryForHolding(holding);
    if (category == MarketCategory.cripto) {
      return const [];
    }

    final detail = await globalMarketRepository.getDetail(
      holding.symbol,
      candleLimit: 1,
      dividendLimit: dividendLimit,
    );

    final mapped = mapDistributionPaymentsToPortfolio(
      holding: holding,
      payments: paymentsFromGlobalDividends(detail.dividends, includeProjected: true),
      cutoff: cutoff,
      defaultKind: 'Dividendo',
    );
    return _mergePayments(mapped);
  }

  List<DividendPayment> _mergePayments(List<DividendPayment> items) {
    final merged = <String, DividendPayment>{};
    for (final item in items) {
      merged[item.id] = item;
    }
    return merged.values.toList();
  }
}

final portfolioDividendService = PortfolioDividendService(
  globalMarketRepository: globalMarketRepository,
);
