import 'dart:async';
import 'dart:convert';

import 'package:rico_investidor/core/markets/market_visibility.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/services/portfolio_data_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recentAssetsKey = 'recent_searched_assets_v1';

class RecentSearchedAssetsStorage {
  RecentSearchedAssetsStorage._();
  static final RecentSearchedAssetsStorage instance = RecentSearchedAssetsStorage._();

  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<List<AssetItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentAssetsKey);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items = decoded
          .map((item) => _assetFromJson(item as Map<String, dynamic>))
          .whereType<AssetItem>()
          .toList();
      return PortfolioDataMigration.migrateAssets(items);
    } catch (_) {
      return [];
    }
  }

  Future<void> record(AssetItem asset) async {
    final normalized = asset.symbol.trim().toUpperCase();
    if (normalized.isEmpty) return;

    final items = await load();
    items.removeWhere((item) => item.symbol.toUpperCase() == normalized);
    items.insert(
      0,
      AssetItem(
        symbol: normalized,
        name: asset.name,
        category: asset.category,
        price: asset.price,
        changePercent: asset.changePercent,
        logoUrl: asset.logoUrl,
        dividendYield12m: asset.dividendYield12m,
        priceToBook: asset.priceToBook,
        exchangeMic: asset.exchangeMic,
      ),
    );
    if (items.length > kMaxRecentSearchedAssets) {
      items.removeRange(kMaxRecentSearchedAssets, items.length);
    }
    await _save(items);
  }

  Future<void> remove(String symbol) async {
    final normalized = symbol.trim().toUpperCase();
    final items = await load()
      ..removeWhere((item) => item.symbol.toUpperCase() == normalized);
    await _save(items);
  }

  Future<void> _save(List<AssetItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recentAssetsKey,
      jsonEncode(items.map(_assetToJson).toList()),
    );
    _changes.add(null);
  }

  Map<String, dynamic> _assetToJson(AssetItem asset) => {
        'symbol': asset.symbol,
        'name': asset.name,
        'category': asset.category.name,
        'price': asset.price,
        'change_percent': asset.changePercent,
        if (asset.logoUrl != null) 'logo_url': asset.logoUrl,
        if (asset.dividendYield12m != null) 'dividend_yield_12m': asset.dividendYield12m,
        if (asset.priceToBook != null) 'price_to_book': asset.priceToBook,
        if (asset.exchangeMic != null) 'exchange_mic': asset.exchangeMic,
      };

  AssetItem? _assetFromJson(Map<String, dynamic> json) {
    final symbol = json['symbol'] as String?;
    if (symbol == null || symbol.isEmpty) return null;

    MarketCategory? category;
    final categoryRaw = json['category'] as String?;
    if (categoryRaw != null) {
      for (final value in MarketCategory.values) {
        if (value.name == categoryRaw) {
          category = value;
          break;
        }
      }
    }

    return AssetItem(
      symbol: symbol,
      name: json['name'] as String? ?? symbol,
      category: resolveMarketCategory(symbol: symbol, stored: category),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0,
      logoUrl: json['logo_url'] as String?,
      dividendYield12m: (json['dividend_yield_12m'] as num?)?.toDouble(),
      priceToBook: (json['price_to_book'] as num?)?.toDouble(),
      exchangeMic: json['exchange_mic'] as String?,
    );
  }
}

final recentSearchedAssetsStorage = RecentSearchedAssetsStorage.instance;
