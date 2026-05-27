import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioPriceService {
  const PortfolioPriceService({
    required this.quoteRepository,
  });

  final QuoteRepository quoteRepository;

  Future<bool> refreshAll(PortfolioState portfolio) {
    return quoteRepository.refreshPortfolioPrices(portfolio);
  }
}
