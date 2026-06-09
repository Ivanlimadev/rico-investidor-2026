class PortfolioTransaction {
  const PortfolioTransaction({
    required this.id,
    required this.symbol,
    required this.name,
    required this.transactionType,
    required this.date,
    required this.quantity,
    required this.pricePerUnit,
    required this.fees,
    this.broker,
    required this.currency,
    this.category,
    required this.createdAt,
  });

  final String id;
  final String symbol;
  final String name;
  final String transactionType;
  final DateTime date;
  final double quantity;
  final double pricePerUnit;
  final double fees;
  final String? broker;
  final String currency;
  final String? category;
  final DateTime createdAt;

  bool get isBuy => transactionType == 'buy';

  double get totalCost => (quantity * pricePerUnit) + fees;

  factory PortfolioTransaction.fromJson(Map<String, dynamic> json) {
    return PortfolioTransaction(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      transactionType: json['transaction_type'] as String,
      date: DateTime.parse(json['date'] as String),
      quantity: (json['quantity'] as num).toDouble(),
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      fees: (json['fees'] as num?)?.toDouble() ?? 0,
      broker: json['broker'] as String?,
      currency: json['currency'] as String? ?? 'usd',
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PortfolioTransactionListResponse {
  const PortfolioTransactionListResponse({required this.items});

  final List<PortfolioTransaction> items;

  factory PortfolioTransactionListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return PortfolioTransactionListResponse(
      items: raw
          .map((item) => PortfolioTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
