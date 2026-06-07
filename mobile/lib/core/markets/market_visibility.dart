import 'package:rico_investidor/core/search/asset_search_ranking.dart';
import 'package:rico_investidor/core/utils/crypto_ticker_utils.dart';
import 'package:rico_investidor/models/market_category.dart';

/// App focado em mercado americano + cripto (sem B3).
const visibleMarketCategories = <MarketCategory>[
  MarketCategory.stocks,
  MarketCategory.reits,
  MarketCategory.cripto,
];

bool isMarketCategoryVisible(MarketCategory category) {
  return visibleMarketCategories.contains(category);
}

Iterable<MarketCategory> get navigableMarketCategories {
  return MarketCategory.values.where(isMarketCategoryVisible);
}

/// Corrige categorias legadas BR salvas no disco para o mercado US/cripto.
MarketCategory resolveMarketCategory({
  required String symbol,
  MarketCategory? stored,
  MarketCategory? inferred,
}) {
  final candidate = stored ?? inferred;
  if (candidate != null && isMarketCategoryVisible(candidate)) {
    return candidate;
  }

  if (looksLikeObviousCryptoTicker(symbol)) {
    return MarketCategory.cripto;
  }

  return inferred ?? MarketCategory.stocks;
}
