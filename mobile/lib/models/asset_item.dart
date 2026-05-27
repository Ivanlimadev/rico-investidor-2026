import 'package:rico_investidor/models/market_category.dart';

class AssetItem {
  const AssetItem({
    required this.symbol,
    required this.name,
    required this.category,
    required this.price,
    required this.changePercent,
    this.logoUrl,
    this.dividendYield12m,
    this.priceToBook,
  });

  final String symbol;
  final String name;
  final MarketCategory category;
  final double price;
  final double changePercent;
  final String? logoUrl;
  final double? dividendYield12m;
  final double? priceToBook;

  bool get isPositive => changePercent >= 0;
}
