import 'package:rico_investidor/models/market_category.dart';

class RelatedAssetItemDto {
  const RelatedAssetItemDto({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.category,
    required this.reason,
    this.logoUrl,
    this.exchangeMic,
    this.provider = '',
  });

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final String category;
  final String reason;
  final String? logoUrl;
  final String? exchangeMic;
  final String provider;

  factory RelatedAssetItemDto.fromJson(Map<String, dynamic> json) {
    return RelatedAssetItemDto(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      exchangeMic: json['exchange_mic'] as String?,
      provider: json['provider'] as String? ?? '',
    );
  }

  MarketCategory get marketCategory => _parseCategory(category);

  static MarketCategory _parseCategory(String slug) {
    return switch (slug) {
      'bdr' => MarketCategory.bdr,
      'etf' => MarketCategory.etf,
      'reits' => MarketCategory.reits,
      'cripto' => MarketCategory.cripto,
      'fiis' => MarketCategory.fiis,
      'stocks' => MarketCategory.stocks,
      _ => MarketCategory.acoesBr,
    };
  }
}

class RelatedAssetsResponseDto {
  const RelatedAssetsResponseDto({
    required this.ticker,
    required this.groupLabel,
    required this.items,
    required this.count,
    required this.market,
  });

  final String ticker;
  final String groupLabel;
  final List<RelatedAssetItemDto> items;
  final int count;
  final String market;

  factory RelatedAssetsResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return RelatedAssetsResponseDto(
      ticker: json['ticker'] as String? ?? '',
      groupLabel: json['group_label'] as String? ?? '',
      items: raw.map((e) => RelatedAssetItemDto.fromJson(e as Map<String, dynamic>)).toList(),
      count: (json['count'] as num?)?.toInt() ?? raw.length,
      market: json['market'] as String? ?? '',
    );
  }
}

String relatedMarketSlug(MarketCategory category) {
  return switch (category) {
    MarketCategory.acoesBr => 'acoes_br',
    MarketCategory.bdr => 'bdr',
    MarketCategory.etf => 'etf',
    MarketCategory.etfInternacional => 'etf',
    MarketCategory.stocks => 'stocks',
    MarketCategory.reits => 'reits',
    MarketCategory.cripto => 'cripto',
    MarketCategory.fiis => 'fiis',
    MarketCategory.moeda => 'moeda',
    MarketCategory.indices => 'indices',
    MarketCategory.tesouroDireto => 'tesouro',
  };
}
