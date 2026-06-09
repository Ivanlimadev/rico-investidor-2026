import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';

class FinancesApiClient {
  FinancesApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<FinanceSummary> getSummary({String? month}) {
    return _client.getJson(
      '/v1/finances/summary',
      query: month == null ? null : {'month': month},
      fromJson: FinanceSummary.fromJson,
    );
  }

  Future<FinanceBudget> getBudget({String? month}) {
    return _client.getJson(
      '/v1/finances/budget',
      query: month == null ? null : {'month': month},
      fromJson: FinanceBudget.fromJson,
    );
  }

  Future<List<PlaidAccount>> listAccounts() async {
    final response = await _client.getJson(
      '/v1/finances/accounts',
      fromJson: (json) => json,
    );
    final raw = response['items'] as List<dynamic>? ?? const [];
    return raw
        .map((item) => PlaidAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FinanceTransaction>> listTransactions({
    String? month,
    String? category,
    int limit = 100,
  }) async {
    final response = await _client.getJson(
      '/v1/finances/transactions',
      query: {
        if (month != null) 'month': month,
        if (category != null) 'category': category,
        'limit': '$limit',
      },
      fromJson: (json) => json,
    );
    final raw = response['items'] as List<dynamic>? ?? const [];
    return raw
        .map((item) => FinanceTransaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FinanceBills> listBills() {
    return _client.getJson(
      '/v1/finances/bills',
      fromJson: FinanceBills.fromJson,
    );
  }

  Future<String> createLinkToken() async {
    final response = await _client.postJson(
      '/v1/finances/link-token',
      fromJson: (json) => json,
    );
    return response['link_token'] as String? ?? '';
  }

  Future<ExchangeTokenResult> exchangePublicToken(String publicToken) {
    return _client.postJson(
      '/v1/finances/exchange-token',
      body: {'public_token': publicToken},
      fromJson: ExchangeTokenResult.fromJson,
    );
  }

  Future<FinanceTransaction> updateTransaction(
    String id, {
    String? category,
    String? subcategory,
    String? note,
  }) {
    return _client.patchJson(
      '/v1/finances/transactions/$id',
      body: {
        if (category != null) 'category': category,
        if (subcategory != null) 'subcategory': subcategory,
        if (note != null) 'note': note,
      },
      fromJson: FinanceTransaction.fromJson,
    );
  }

  Future<FinanceBudget> upsertBudget({
    required String month,
    required List<FinanceBudgetCategory> categories,
    String mode = 'categories',
  }) {
    return _client.putJson(
      '/v1/finances/budget',
      body: {
        'month': month,
        'mode': mode,
        'categories': categories
            .map(
              (item) => {
                'category': item.category,
                'limit': item.limit,
                'spent': item.spent,
              },
            )
            .toList(),
      },
      fromJson: FinanceBudget.fromJson,
    );
  }

  Future<void> deleteAccount(String id) async {
    await _client.deleteJson(
      '/v1/finances/accounts/$id',
      fromJson: (json) => json,
    );
  }

  Future<FinanceTransaction> createTransaction({
    required double amount,
    required String name,
    String? merchantName,
    String category = 'other',
    String? note,
    DateTime? date,
  }) {
    return _client.postJson(
      '/v1/finances/transactions',
      body: {
        'amount': amount,
        'name': name,
        if (merchantName != null) 'merchant_name': merchantName,
        'category': category,
        if (note != null) 'note': note,
        if (date != null) 'date': date.toIso8601String().split('T').first,
      },
      fromJson: FinanceTransaction.fromJson,
    );
  }
}

final financesApiClient = FinancesApiClient();
