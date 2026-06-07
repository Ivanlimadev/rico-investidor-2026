import 'package:rico_investidor/models/market_category.dart';

/// Hub principal dos EUA — foco da interface.
const usMarketCategories = <MarketCategory>[
  MarketCategory.stocks,
  MarketCategory.reits,
];

/// Mercados secundários exibidos fora do hub EUA.
const secondaryMarketCategories = <MarketCategory>[
  MarketCategory.cripto,
];

bool isUsMarketCategory(MarketCategory category) {
  return usMarketCategories.contains(category);
}

int? usMarketTotalAssets(int? stocksUsCount) {
  if (stocksUsCount == null || stocksUsCount <= 0) return null;
  return stocksUsCount;
}
