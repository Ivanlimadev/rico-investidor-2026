import 'package:rico_investidor/core/markets/market_visibility.dart';
import 'package:rico_investidor/core/search/asset_search_ranking.dart';
import 'package:rico_investidor/core/utils/market_category_storage.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

/// Normaliza dados legados BR (B3/FII/BRL) para mercado americano + cripto.
class PortfolioDataMigration {
  const PortfolioDataMigration._();

  static List<PortfolioHolding> migrateHoldings(List<PortfolioHolding> holdings) {
    return holdings.map(_migrateHolding).toList();
  }

  static PortfolioHolding _migrateHolding(PortfolioHolding holding) {
    final category = resolveMarketCategory(
      symbol: holding.symbol,
      stored: holding.category,
    );
    final currency = resolvedHoldingCurrency(
      holding.copyWith(category: category),
      category: category,
    );
    if (holding.category == category && holding.currency == currency) {
      return holding;
    }
    return holding.copyWith(category: category, currency: currency);
  }

  static List<AssetItem> migrateAssets(Iterable<AssetItem> assets) {
    return assets.map(_migrateAsset).toList();
  }

  static AssetItem _migrateAsset(AssetItem asset) {
    final category = resolveMarketCategory(
      symbol: asset.symbol,
      stored: asset.category,
    );
    if (asset.category == category) return asset;
    return AssetItem(
      symbol: asset.symbol,
      name: asset.name,
      category: category,
      price: asset.price,
      changePercent: asset.changePercent,
      logoUrl: asset.logoUrl,
      dividendYield12m: asset.dividendYield12m,
      priceToBook: asset.priceToBook,
      exchangeMic: asset.exchangeMic,
      sparkline: asset.sparkline,
    );
  }

  /// Remove tickers claramente B3/FII que não existem no mercado US.
  static bool isOrphanBrazilTicker(String symbol) {
    final normalized = symbol.trim().toUpperCase();
    if (normalized.isEmpty) return true;
    if (looksLikeObviousCryptoTicker(normalized)) return false;
    if (RegExp(r'^[A-Z]{1,5}([.-][A-Z])?$').hasMatch(normalized)) return false;
    if (RegExp(r'^[A-Z]{4}\d{1,2}$').hasMatch(normalized)) return true;
    if (normalized.endsWith('11')) return true;
    return false;
  }

  static List<PortfolioHolding> dropOrphanBrazilHoldings(List<PortfolioHolding> holdings) {
    return holdings.where((h) => !isOrphanBrazilTicker(h.symbol)).toList();
  }

  static String? migrateStoredCategory(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = marketCategoryFromStorage(raw);
    if (parsed == null) return null;
    if (isMarketCategoryVisible(parsed)) {
      return marketCategoryToStorage(parsed);
    }
    return marketCategoryToStorage(MarketCategory.stocks);
  }
}
