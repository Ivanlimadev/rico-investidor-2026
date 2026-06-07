import 'package:rico_investidor/models/market_category.dart';

/// Categorias com cotações reais (Marketstack / Binance / backend).
const liveMarketCategories = {
  MarketCategory.cripto,
  MarketCategory.stocks,
  MarketCategory.reits,
};

extension MarketCategoryAvailability on MarketCategory {
  bool get hasLiveData => liveMarketCategories.contains(this);
}
