import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/utils/market_category_storage.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

class PortfolioHoldingsResponse {
  const PortfolioHoldingsResponse({required this.items});

  final List<PortfolioHolding> items;

  factory PortfolioHoldingsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return PortfolioHoldingsResponse(
      items: raw
          .map((item) => PortfolioHolding.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PortfolioApiClient {
  PortfolioApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<List<PortfolioHolding>> listHoldings() async {
    final response = await _client.getJson(
      '/v1/portfolio/holdings',
      fromJson: PortfolioHoldingsResponse.fromJson,
    );
    return response.items;
  }

  Future<List<PortfolioHolding>> syncHoldings(List<PortfolioHolding> holdings) async {
    final response = await _client.postJson(
      '/v1/portfolio/holdings/sync',
      body: {
        'items': holdings.map(_holdingPayload).toList(),
      },
      fromJson: PortfolioHoldingsResponse.fromJson,
    );
    return response.items;
  }

  Future<List<PortfolioHolding>> createHolding(PortfolioHolding holding) async {
    final response = await _client.postJson(
      '/v1/portfolio/holdings',
      body: _holdingPayload(holding),
      fromJson: PortfolioHoldingsResponse.fromJson,
    );
    return response.items;
  }

  Future<List<PortfolioHolding>> deleteHolding(String holdingId) async {
    final response = await _client.deleteJson(
      '/v1/portfolio/holdings/$holdingId',
      fromJson: PortfolioHoldingsResponse.fromJson,
    );
    return response.items;
  }

  static Map<String, dynamic> _holdingPayload(PortfolioHolding holding) => {
        if (holding.id.isNotEmpty) 'id': holding.id,
        'symbol': holding.symbol,
        'name': holding.name,
        'quantity': holding.quantity,
        'average_price': holding.averagePrice,
        'current_price': holding.currentPrice,
        'change_percent': holding.changePercent,
        'currency': holding.currency.code,
        if (holding.category != null)
          'category': marketCategoryToStorage(holding.category),
      };
}

final portfolioApiClient = PortfolioApiClient();
