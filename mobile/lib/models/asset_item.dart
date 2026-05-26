import 'package:rico_investidor/models/market_category.dart';

class AssetItem {
  const AssetItem({
    required this.symbol,
    required this.name,
    required this.category,
    required this.price,
    required this.changePercent,
  });

  final String symbol;
  final String name;
  final MarketCategory category;
  final double price;
  final double changePercent;

  bool get isPositive => changePercent >= 0;
}
