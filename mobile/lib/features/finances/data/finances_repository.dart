import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/finances/data/finances_api_client.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/utils/finance_month.dart';

class FinancesRepository {
  FinancesRepository({FinancesApiClient? api}) : _api = api ?? financesApiClient;

  final FinancesApiClient _api;

  FinancesDashboardData? _cached;
  DateTime? _cachedAt;

  bool get canAccess => authSession.isRegisteredSession;

  FinancesDashboardData? get cachedDashboard => _cached;

  bool get hasFreshCache {
    if (_cached == null || _cachedAt == null) return false;
    return DateTime.now().difference(_cachedAt!) < const Duration(seconds: 30);
  }

  Future<FinancesDashboardData> loadDashboard({bool forceRefresh = false}) async {
    if (!forceRefresh && hasFreshCache) {
      return _cached!;
    }

    final results = await Future.wait([
      _api.getSummary(),
      _api.getBudget(),
      _api.listAccounts(),
      _api.listTransactions(limit: 50),
      _api.listBills(),
    ]);

    final data = FinancesDashboardData(
      summary: results[0] as FinanceSummary,
      budget: results[1] as FinanceBudget,
      accounts: results[2] as List<PlaidAccount>,
      transactions: results[3] as List<FinanceTransaction>,
      bills: results[4] as FinanceBills,
      fetchedAt: DateTime.now(),
    );

    _cached = data;
    _cachedAt = data.fetchedAt;
    return data;
  }

  void invalidateCache() {
    _cached = null;
    _cachedAt = null;
  }

  Future<String> createLinkToken() => _api.createLinkToken();

  Future<ExchangeTokenResult> exchangePublicToken(String publicToken) async {
    final result = await _api.exchangePublicToken(publicToken);
    invalidateCache();
    return result;
  }

  Future<List<FinanceTransaction>> listTransactions({
    String? month,
    String? category,
    int limit = 200,
  }) {
    return _api.listTransactions(month: month, category: category, limit: limit);
  }

  Future<FinanceBudget> loadBudget({String? month}) => _api.getBudget(month: month);

  Future<FinanceTransaction> updateTransaction(
    String id, {
    String? category,
    String? subcategory,
    String? note,
  }) async {
    final tx = await _api.updateTransaction(
      id,
      category: category,
      subcategory: subcategory,
      note: note,
    );
    invalidateCache();
    return tx;
  }

  Future<FinanceBudget> saveBudget({
    required String month,
    required List<FinanceBudgetCategory> categories,
    String mode = 'categories',
  }) async {
    final budget = await _api.upsertBudget(
      month: month,
      categories: categories,
      mode: mode,
    );
    invalidateCache();
    return budget;
  }

  Future<FinanceSummary> loadSummary({String? month}) => _api.getSummary(month: month);

  Future<List<FinanceSummary>> loadMonthlySummaries({int months = 6}) async {
    final keys = <String>[];
    var key = currentFinanceMonthKey;
    for (var i = 0; i < months; i++) {
      keys.add(key);
      key = shiftFinanceMonth(key, -1);
    }
    keys.sort();
    final summaries = await Future.wait(keys.map((month) => _api.getSummary(month: month)));
    return summaries;
  }

  Future<FinanceBills> loadBills() => _api.listBills();

  Future<List<PlaidAccount>> listAccounts() => _api.listAccounts();

  Future<void> deleteAccount(String id) async {
    await _api.deleteAccount(id);
    invalidateCache();
  }

  Future<FinanceTransaction> addManualTransaction({
    required double amount,
    required String name,
    String? merchantName,
    String category = 'other',
    String? note,
  }) async {
    final tx = await _api.createTransaction(
      amount: amount,
      name: name,
      merchantName: merchantName,
      category: category,
      note: note,
    );
    invalidateCache();
    return tx;
  }
}

final financesRepository = FinancesRepository();
