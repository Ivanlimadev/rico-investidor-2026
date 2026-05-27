class PortfolioHolding {
  const PortfolioHolding({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    this.changePercent = 0,
  });

  final String id;
  final String symbol;
  final String name;
  final double quantity;
  final double averagePrice;
  final double currentPrice;
  final double changePercent;

  double get invested => quantity * averagePrice;
  double get marketValue => quantity * currentPrice;
  double get profit => marketValue - invested;
  double get profitPercent => invested == 0 ? 0 : (profit / invested) * 100;

  PortfolioHolding copyWith({
    double? quantity,
    double? averagePrice,
    double? currentPrice,
    double? changePercent,
  }) {
    return PortfolioHolding(
      id: id,
      symbol: symbol,
      name: name,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
      currentPrice: currentPrice ?? this.currentPrice,
      changePercent: changePercent ?? this.changePercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'quantity': quantity,
        'average_price': averagePrice,
        'current_price': currentPrice,
        'change_percent': changePercent,
      };

  factory PortfolioHolding.fromJson(Map<String, dynamic> json) {
    return PortfolioHolding(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      averagePrice: (json['average_price'] as num).toDouble(),
      currentPrice: (json['current_price'] as num).toDouble(),
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}
