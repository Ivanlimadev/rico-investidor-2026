import 'package:rico_investidor/models/market_category.dart';

/// Categorias com cotações reais (Brapi / Marketstack / backend).
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
  MarketCategory.stocks,
  MarketCategory.reits,
};

extension MarketCategoryAvailability on MarketCategory {
  bool get hasLiveData => liveMarketCategories.contains(this);
}
