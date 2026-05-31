import 'package:rico_investidor/models/market_category.dart';

/// Hub principal dos EUA — foco da interface.
const usMarketCategories = <MarketCategory>[
  MarketCategory.stocks,
  MarketCategory.reits,
];

/// Mercados secundários exibidos fora dos hubs EUA e Brasil.
const secondaryMarketCategories = <MarketCategory>[
  MarketCategory.cripto,
  MarketCategory.etfInternacional,
];

bool isUsMarketCategory(MarketCategory category) {
  return usMarketCategories.contains(category);
}

int? usMarketTotalAssets(int? stocksUsCount) {
  if (stocksUsCount == null || stocksUsCount <= 0) return null;
  return stocksUsCount;
}
