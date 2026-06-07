import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/portfolio/data/portfolio_api_client.dart';
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
}

final portfolioRepository = PortfolioRepository();
