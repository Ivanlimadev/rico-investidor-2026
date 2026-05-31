import 'dart:async';
import 'dart:convert';

import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _favoritesKey = 'asset_favorites_v1';

class FavoritesStorage {
  FavoritesStorage._();
  static final FavoritesStorage instance = FavoritesStorage._();

  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<List<AssetItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => _assetFromJson(item as Map<String, dynamic>))
        .whereType<AssetItem>()
        .toList();
  }

  Future<bool> isFavorite(String symbol) async {
    final normalized = symbol.trim().toUpperCase();
    final items = await load();
    return items.any((item) => item.symbol.toUpperCase() == normalized);
  }

  Future<void> toggle(AssetItem asset) async {
    final normalized = asset.symbol.trim().toUpperCase();
    final items = await load();
    final index = items.indexWhere((item) => item.symbol.toUpperCase() == normalized);

    if (index >= 0) {
      items.removeAt(index);
    } else {
      items.add(
        AssetItem(
          symbol: normalized,
          name: asset.name,
          category: asset.category,
          price: asset.price,
          changePercent: asset.changePercent,
          logoUrl: asset.logoUrl,
          dividendYield12m: asset.dividendYield12m,
          priceToBook: asset.priceToBook,
        ),
      );
    }

    await _save(items);
  }

  Future<void> remove(String symbol) async {
    final normalized = symbol.trim().toUpperCase();
    final items = await load();
    items.removeWhere((item) => item.symbol.toUpperCase() == normalized);
    await _save(items);
  }

  Future<void> _save(List<AssetItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritesKey,
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
      category: category ?? MarketCategory.acoesBr,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0,
      logoUrl: json['logo_url'] as String?,
      dividendYield12m: (json['dividend_yield_12m'] as num?)?.toDouble(),
      priceToBook: (json['price_to_book'] as num?)?.toDouble(),
    );
  }
}

final favoritesStorage = FavoritesStorage.instance;
