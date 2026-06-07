import 'package:rico_investidor/models/market_category.dart';

String? marketCategoryToStorage(MarketCategory? category) => category?.name;

const _legacyCategorySlugs = <String, MarketCategory>{
  'acoesBr': MarketCategory.stocks,
  'fiis': MarketCategory.reits,
  'bdr': MarketCategory.stocks,
  'etf': MarketCategory.stocks,
  'moeda': MarketCategory.stocks,
  'indices': MarketCategory.stocks,
  'etfInternacional': MarketCategory.stocks,
  'tesouroDireto': MarketCategory.stocks,
};

MarketCategory? marketCategoryFromStorage(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  for (final category in MarketCategory.values) {
    if (category.name == raw) return category;
  }

  return _legacyCategorySlugs[raw];
}
