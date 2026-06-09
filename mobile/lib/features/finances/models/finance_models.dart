class FinanceSummary {
  const FinanceSummary({
    required this.incomeMtd,
    required this.expensesMtd,
    required this.balance,
    required this.vsLastMonth,
    required this.month,
  });

  final double incomeMtd;
  final double expensesMtd;
  final double balance;
  final double vsLastMonth;
  final String month;

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      incomeMtd: (json['income_mtd'] as num?)?.toDouble() ?? 0,
      expensesMtd: (json['expenses_mtd'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      vsLastMonth: (json['vs_last_month'] as num?)?.toDouble() ?? 0,
      month: json['month'] as String? ?? '',
    );
  }
}

class FinanceBudgetCategory {
  const FinanceBudgetCategory({
    required this.category,
    required this.limit,
    required this.spent,
  });

  final String category;
  final double limit;
  final double spent;

  double get remaining => limit - spent;
  double get percent => limit > 0 ? spent / limit : 0;
  bool get isOverBudget => spent > limit;

  factory FinanceBudgetCategory.fromJson(Map<String, dynamic> json) {
    return FinanceBudgetCategory(
      category: json['category'] as String? ?? 'other',
      limit: (json['limit'] as num?)?.toDouble() ?? 0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FinanceBudget {
  const FinanceBudget({
    required this.month,
    required this.categories,
    this.mode = 'categories',
  });

  final String month;
  final String mode;
  final List<FinanceBudgetCategory> categories;

  factory FinanceBudget.fromJson(Map<String, dynamic> json) {
    final raw = json['categories'] as List<dynamic>? ?? const [];
    return FinanceBudget(
      month: json['month'] as String? ?? '',
      mode: json['mode'] as String? ?? 'categories',
      categories: raw
          .map((item) => FinanceBudgetCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlaidAccount {
  const PlaidAccount({
    required this.id,
    required this.name,
    required this.mask,
    required this.type,
    required this.currentBalance,
    required this.institutionName,
    this.subtype,
    this.availableBalance,
  });

  final String id;
  final String name;
  final String mask;
  final String type;
  final String? subtype;
  final double currentBalance;
  final double? availableBalance;
  final String institutionName;

  factory PlaidAccount.fromJson(Map<String, dynamic> json) {
    return PlaidAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Conta',
      mask: json['mask'] as String? ?? '',
      type: json['type'] as String? ?? 'depository',
      subtype: json['subtype'] as String?,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
      availableBalance: (json['available_balance'] as num?)?.toDouble(),
      institutionName: json['institution_name'] as String? ?? 'Banco',
    );
  }
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.amount,
    required this.date,
    required this.name,
    required this.category,
    this.merchantName,
    this.subcategory,
    this.isPending = false,
    this.isManual = false,
    this.note,
    this.accountId,
    this.accountName,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String? merchantName;
  final String name;
  final String category;
  final String? subcategory;
  final bool isPending;
  final bool isManual;
  final String? note;
  final String? accountId;
  final String? accountName;

  bool get isExpense => amount < 0;
  bool get isIncome => amount > 0;

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String? ?? '';
    return FinanceTransaction(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      merchantName: json['merchant_name'] as String?,
      name: json['name'] as String? ?? 'Transação',
      category: json['category'] as String? ?? 'other',
      subcategory: json['subcategory'] as String?,
      isPending: json['is_pending'] as bool? ?? false,
      isManual: json['is_manual'] as bool? ?? false,
      note: json['note'] as String?,
      accountId: json['account_id'] as String?,
      accountName: json['account_name'] as String?,
    );
  }
}

class RecurringBill {
  const RecurringBill({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.frequency,
    required this.category,
    this.nextDate,
    this.isActive = true,
  });

  final String id;
  final String merchantName;
  final double amount;
  final String frequency;
  final DateTime? nextDate;
  final String category;
  final bool isActive;

  factory RecurringBill.fromJson(Map<String, dynamic> json) {
    final rawDate = json['next_date'] as String?;
    return RecurringBill(
      id: json['id'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? 'Assinatura',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      frequency: json['frequency'] as String? ?? 'monthly',
      nextDate: rawDate == null ? null : DateTime.tryParse(rawDate),
      category: json['category'] as String? ?? 'other',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class FinanceBills {
  const FinanceBills({
    required this.items,
    required this.monthlyTotal,
    required this.count,
  });

  final List<RecurringBill> items;
  final double monthlyTotal;
  final int count;

  factory FinanceBills.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return FinanceBills(
      items: raw
          .map((item) => RecurringBill.fromJson(item as Map<String, dynamic>))
          .toList(),
      monthlyTotal: (json['monthly_total'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExchangeTokenResult {
  const ExchangeTokenResult({
    required this.institutionName,
    required this.accountCount,
  });

  final String institutionName;
  final int accountCount;

  factory ExchangeTokenResult.fromJson(Map<String, dynamic> json) {
    return ExchangeTokenResult(
      institutionName: json['institution_name'] as String? ?? 'Banco conectado',
      accountCount: (json['account_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FinancesDashboardData {
  const FinancesDashboardData({
    required this.summary,
    required this.budget,
    required this.accounts,
    required this.transactions,
    required this.bills,
    this.fetchedAt,
  });

  final FinanceSummary summary;
  final FinanceBudget budget;
  final List<PlaidAccount> accounts;
  final List<FinanceTransaction> transactions;
  final FinanceBills bills;
  final DateTime? fetchedAt;

  bool get hasConnectedBank => accounts.isNotEmpty;

  List<CategorySpending> topCategorySpending({int limit = 4}) {
    final totals = <String, double>{};
    for (final tx in transactions) {
      if (tx.isPending || tx.isExpense == false || tx.category == 'transfers') continue;
      totals[tx.category] = (totals[tx.category] ?? 0) + tx.amount.abs();
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => CategorySpending(category: e.key, amount: e.value))
        .toList();
  }
}

class CategorySpending {
  const CategorySpending({required this.category, required this.amount});

  final String category;
  final double amount;
}
