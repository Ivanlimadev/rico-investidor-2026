import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/portfolio/utils/portfolio_dividend_mapper.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

/// Sincroniza proventos reais da API com base nas posições da carteira.
///
/// Total recebido = valor/cota (API) × quantidade na carteira.
class PortfolioDividendService {
  const PortfolioDividendService({
    required this.quoteRepository,
    required this.fiiRepository,
    this.lookbackYears = 5,
    this.dividendLimit = 500,
  });

  final QuoteRepository quoteRepository;
  final FiiRepository fiiRepository;
  final int lookbackYears;
  final int dividendLimit;

  Future<bool> syncPortfolioDividends(PortfolioState portfolio) async {
    if (portfolio.holdings.isEmpty) {
      portfolio.replaceDividends(const []);
      return true;
    }

    final cutoff = _cutoffDate();
    final batches = await Future.wait(
      portfolio.holdings.map((holding) => _fetchForHolding(holding, cutoff)),
      eagerError: false,
    );

    final merged = <String, DividendPayment>{};
    for (final batch in batches) {
      for (final payment in batch) {
        merged[payment.id] = payment;
      }
    }

    final sorted = merged.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    portfolio.replaceDividends(sorted);
    return sorted.isNotEmpty || portfolio.holdings.isEmpty;
  }

  DateTime _cutoffDate() {
    final now = DateTime.now();
    return DateTime(now.year - lookbackYears, now.month, now.day);
  }

  Future<List<DividendPayment>> _fetchForHolding(
    PortfolioHolding holding,
    DateTime cutoff,
  ) async {
    try {
      if (isFiiTicker(holding.symbol)) {
        final distributions = await fiiRepository.getDistributions(
          holding.symbol,
          years: lookbackYears,
        );
        return mapDistributionPaymentsToPortfolio(
          holding: holding,
          payments: distributions.payments,
          cutoff: cutoff,
          defaultKind: 'Rendimento',
        );
      }

      final detail = await quoteRepository.getStockDetail(
        holding.symbol,
        candleLimit: 1,
        dividendLimit: dividendLimit,
      );
      return mapDistributionPaymentsToPortfolio(
        holding: holding,
        payments: detail.dividends.payments,
        cutoff: cutoff,
        defaultKind: 'Dividendo',
      );
    } catch (_) {
      return const [];
    }
  }
}

final portfolioDividendService = PortfolioDividendService(
  quoteRepository: quoteRepository,
  fiiRepository: fiiRepository,
);
