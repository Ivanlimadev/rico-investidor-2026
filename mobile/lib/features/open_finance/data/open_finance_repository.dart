import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/models/open_finance_models.dart';

class OpenFinanceRepository {
  OpenFinanceRepository({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<String> createConnectToken() async {
    final response = await _client.postJson(
      '/v1/open-finance/connect-token',
      body: const {},
      fromJson: (json) => json,
    );
    final token = response['connect_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Token de conexão inválido');
    }
    return token;
  }

  Future<void> registerItem({required String itemId}) async {
    await _client.postJson(
      '/v1/open-finance/items',
      body: {'item_id': itemId},
      fromJson: (json) => json,
    );
  }

  Future<OpenFinanceStatus> fetchStatus() async {
    return _client.getJson(
      '/v1/open-finance/status',
      fromJson: OpenFinanceStatus.fromJson,
    );
  }

  Future<OpenFinanceSyncResponse> syncPortfolio() async {
    return _client.postJson(
      '/v1/open-finance/sync',
      body: const {},
      fromJson: OpenFinanceSyncResponse.fromJson,
    );
  }
}

final openFinanceRepository = OpenFinanceRepository();
