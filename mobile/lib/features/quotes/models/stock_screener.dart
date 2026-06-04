import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';

class StockScreenerItemDto {
  const StockScreenerItemDto({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.category,
    this.sector,
    this.marketCap,
    this.volume,
    this.logoUrl,
    this.dividendYield12m,
    this.priceEarnings,
    this.returnOnEquity,
    this.priceToBook,
    this.provider = 'brapi',
    this.sparkline = const [],
  });

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final String category;
  final String? sector;
  final double? marketCap;
  final double? volume;
  final String? logoUrl;
  final double? dividendYield12m;
  final double? priceEarnings;
  final double? returnOnEquity;
  final double? priceToBook;
  final String provider;
  final List<double> sparkline;

  bool get isPositive => changePercent >= 0;

  factory StockScreenerItemDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return StockScreenerItemDto(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      changePercent: (json['change_percent'] as num).toDouble(),
      category: json['category'] as String? ?? 'acoes_br',
      sector: json['sector'] as String?,
      marketCap: numVal('market_cap'),
      volume: numVal('volume'),
      logoUrl: json['logo_url'] as String?,
      dividendYield12m: numVal('dividend_yield_12m'),
      priceEarnings: numVal('price_earnings'),
      returnOnEquity: numVal('return_on_equity'),
      priceToBook: numVal('price_to_book'),
      provider: json['provider'] as String? ?? 'brapi',
      sparkline: (json['sparkline'] as List<dynamic>?)
              ?.map((value) => (value as num).toDouble())
              .toList() ??
          const [],
    );
  }

  AssetItem toAssetItem() {
    return AssetItem(
      symbol: symbol,
      name: name,
      category: _parseCategory(category),
      price: price,
      changePercent: changePercent,
      logoUrl: resolveAssetLogoUrl(symbol, logoUrl, isFii: false),
      dividendYield12m: dividendYield12m,
      priceToBook: priceToBook,
      sparkline: sparkline,
    );
  }

  MarketCategory _parseCategory(String slug) {
    return switch (slug) {
      'bdr' => MarketCategory.bdr,
      'etf' => MarketCategory.etf,
      _ => MarketCategory.acoesBr,
    };
  }
}

class StockScreenerResponseDto {
  const StockScreenerResponseDto({
    required this.items,
    required this.count,
    this.total,
    this.page = 1,
    this.totalPages,
    this.sectors = const [],
    this.provider = 'brapi',
  });

  final List<StockScreenerItemDto> items;
  final int count;
  final int? total;
  final int page;
  final int? totalPages;
  final List<String> sectors;
  final String provider;

  factory StockScreenerResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    final rawSectors = json['sectors'] as List<dynamic>? ?? const [];

    return StockScreenerResponseDto(
      items: raw.map((item) => StockScreenerItemDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      total: json['total'] as int?,
      page: json['page'] as int? ?? 1,
      totalPages: json['total_pages'] as int?,
      sectors: rawSectors.map((item) => item as String).toList(),
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}
