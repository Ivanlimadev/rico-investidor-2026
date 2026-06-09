import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/portfolio/data/portfolio_api_client.dart';
import 'package:rico_investidor/features/portfolio/models/portfolio_transaction.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

class PortfolioRepository {
  PortfolioRepository({PortfolioApiClient? api}) : _api = api ?? portfolioApiClient;

  final PortfolioApiClient _api;

  bool get canSync => authSession.isRegisteredSession;

  Future<List<PortfolioHolding>> fetchRemoteHoldings() {
    return _api.listHoldings();
  }

  Future<List<PortfolioHolding>> syncLocalHoldings(List<PortfolioHolding> holdings) {
    return _api.syncHoldings(holdings);
  }

  Future<List<PortfolioHolding>> pushHolding(PortfolioHolding holding) {
    return _api.createHolding(holding);
  }

  Future<List<PortfolioHolding>> removeRemoteHolding(String holdingId) {
    return _api.deleteHolding(holdingId);
  }

  Future<List<PortfolioTransaction>> fetchTransactions({String? symbol}) {
    return _api.listTransactions(symbol: symbol);
  }

  Future<List<PortfolioHolding>> addTransaction({
    required String symbol,
    required String name,
    required String transactionType,
    required DateTime date,
    required double quantity,
    required double pricePerUnit,
    required double fees,
    String? broker,
    required String currency,
    String? category,
  }) {
    return _api.addTransaction(
      symbol: symbol,
      name: name,
      transactionType: transactionType,
      date: date,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      fees: fees,
      broker: broker,
      currency: currency,
      category: category,
    );
  }

  Future<List<PortfolioHolding>> deleteTransaction(String transactionId) {
    return _api.deleteTransaction(transactionId);
  }
}

final portfolioRepository = PortfolioRepository();
