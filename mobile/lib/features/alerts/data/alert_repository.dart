import 'package:rico_investidor/features/alerts/data/alert_api_client.dart';
import 'package:rico_investidor/features/alerts/models/price_alert.dart';

class AlertRepository {
  AlertRepository({AlertApiClient? api}) : _api = api ?? AlertApiClient();

  final AlertApiClient _api;

  Future<List<PriceAlert>> listAlerts() async {
    final response = await _api.listAlerts();
    return response.items;
  }

  Future<PriceAlert> createAlert({
    required String symbol,
    required String category,
    required String direction,
    required double targetPrice,
  }) {
    return _api.createAlert(
      symbol: symbol,
      category: category,
      direction: direction,
      targetPrice: targetPrice,
    );
  }

  Future<void> deleteAlert(String alertId) => _api.deleteAlert(alertId);
}

final alertRepository = AlertRepository();
