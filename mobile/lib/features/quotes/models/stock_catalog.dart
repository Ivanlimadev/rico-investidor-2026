import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class StockCatalogItemDto {
  const StockCatalogItemDto({
    required this.symbol,
    required this.name,
    required this.category,
    this.sector,
    this.logoUrl,
    this.provider = 'brapi',
  });

  final String symbol;
  final String name;
  final String category;
  final String? sector;
  final String? logoUrl;
  final String provider;

  factory StockCatalogItemDto.fromJson(Map<String, dynamic> json) {
    return StockCatalogItemDto(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'acoes_br',
      sector: json['sector'] as String?,
      logoUrl: json['logo_url'] as String?,
      provider: json['provider'] as String? ?? 'brapi',
    );
  }

  AssetItem toAssetItem() {
    return AssetItem(
      symbol: symbol,
      name: name,
      category: _parseCategory(category),
      price: 0,
      changePercent: 0,
      logoUrl: logoUrl,
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

class StockCatalogResponseDto {
  const StockCatalogResponseDto({
    required this.items,
    required this.count,
    required this.total,
    this.quoteType = 'stock',
    this.sectors = const [],
    this.provider = 'brapi',
  });

  final List<StockCatalogItemDto> items;
  final int count;
  final int total;
  final String quoteType;
  final List<String> sectors;
  final String provider;

  factory StockCatalogResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    final rawSectors = json['sectors'] as List<dynamic>? ?? const [];

    return StockCatalogResponseDto(
      items: raw.map((item) => StockCatalogItemDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      total: json['total'] as int? ?? raw.length,
      quoteType: json['quote_type'] as String? ?? 'stock',
      sectors: rawSectors.map((item) => item as String).toList(),
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}
