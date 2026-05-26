class PortfolioHolding {
  const PortfolioHolding({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
  });

  final String id;
  final String symbol;
  final String name;
  final double quantity;
  final double averagePrice;
  final double currentPrice;

  double get invested => quantity * averagePrice;
  double get marketValue => quantity * currentPrice;
  double get profit => marketValue - invested;
  double get profitPercent => invested == 0 ? 0 : (profit / invested) * 100;

  PortfolioHolding copyWith({
    double? quantity,
    double? averagePrice,
    double? currentPrice,
  }) {
    return PortfolioHolding(
      id: id,
      symbol: symbol,
      name: name,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
      currentPrice: currentPrice ?? this.currentPrice,
    );
  }
}
