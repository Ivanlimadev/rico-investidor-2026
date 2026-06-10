import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/alerts/models/price_alert.dart';

class AlertApiClient {
  AlertApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<PriceAlertListResponse> listAlerts() {
    return _client.getJson(
      '/v1/alerts',
      fromJson: PriceAlertListResponse.fromJson,
    );
  }

  Future<PriceAlert> createAlert({
    required String symbol,
    required String category,
    required String direction,
    required double targetPrice,
  }) {
    return _client.postJson(
      '/v1/alerts',
      body: {
        'symbol': symbol,
        'category': category,
        'direction': direction,
        'target_price': targetPrice,
      },
      fromJson: PriceAlert.fromJson,
    );
  }

  Future<void> deleteAlert(String alertId) async {
    await _client.deleteJson<Map<String, dynamic>>(
      '/v1/alerts/$alertId',
      fromJson: (json) => json,
    );
  }
}
