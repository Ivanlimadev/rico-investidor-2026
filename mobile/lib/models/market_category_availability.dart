import 'package:rico_investidor/models/market_category.dart';

/// Categorias com cotações reais (Brapi / backend).
const liveMarketCategories = {
  MarketCategory.acoesBr,
  MarketCategory.fiis,
  MarketCategory.bdr,
  MarketCategory.etf,
  MarketCategory.etfInternacional,
  MarketCategory.moeda,
  MarketCategory.tesouroDireto,
  MarketCategory.indices,
  MarketCategory.cripto,
};

/// Categorias apenas ilustrativas até integração futura.
const demoMarketCategories = {
  MarketCategory.stocks,
  MarketCategory.reits,
};

extension MarketCategoryAvailability on MarketCategory {
  bool get hasLiveData => liveMarketCategories.contains(this);

  bool get isDemo => demoMarketCategories.contains(this);
}
