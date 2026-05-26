import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/models/open_finance_models.dart';

class OpenFinanceRepository {
  OpenFinanceRepository({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<String> createConnectToken(String clientUserId) async {
    final response = await _client.postJson(
      '/v1/open-finance/connect-token',
      body: {'client_user_id': clientUserId},
      fromJson: (json) => json,
    );
    final token = response['connect_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Token de conexão inválido');
    }
    return token;
  }

  Future<void> registerItem({
    required String clientUserId,
    required String itemId,
  }) async {
    await _client.postJson(
      '/v1/open-finance/items',
      body: {
        'client_user_id': clientUserId,
        'item_id': itemId,
      },
      fromJson: (json) => json,
    );
  }

  Future<OpenFinanceStatus> fetchStatus(String clientUserId) async {
    return _client.getJson(
      '/v1/open-finance/status',
      query: {'client_user_id': clientUserId},
      fromJson: OpenFinanceStatus.fromJson,
    );
  }

  Future<OpenFinanceSyncResponse> syncPortfolio(String clientUserId) async {
    return _client.postJson(
      '/v1/open-finance/sync',
      body: {'client_user_id': clientUserId},
      fromJson: OpenFinanceSyncResponse.fromJson,
    );
  }
}

final openFinanceRepository = OpenFinanceRepository();
