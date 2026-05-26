import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/market_category.dart';

class AssetDetailDto {
  const AssetDetailDto({
    required this.ticker,
    required this.assetClass,
    required this.category,
    required this.provider,
    required this.kind,
    this.sections = const [],
    this.notes = const [],
    this.stock,
    this.fii,
  });

  final String ticker;
  final String assetClass;
  final MarketCategory category;
  final String provider;
  final String kind;
  final List<String> sections;
  final List<String> notes;
  final StockQuoteDetailDto? stock;
  final FiiDetail? fii;

  bool get isFii => kind == 'fii';

  factory AssetDetailDto.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    return AssetDetailDto(
      ticker: json['ticker'] as String,
      assetClass: json['asset_class'] as String,
      category: _parseCategory(json['category'] as String? ?? 'acoes_br'),
      provider: json['provider'] as String? ?? 'brapi',
      kind: kind,
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      notes: (json['notes'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      stock: kind == 'stock' && json['stock'] != null
          ? StockQuoteDetailDto.fromJson(json['stock'] as Map<String, dynamic>)
          : null,
      fii: kind == 'fii' && json['fii'] != null
          ? FiiDetail.fromJson(json['fii'] as Map<String, dynamic>)
          : null,
    );
  }

  static MarketCategory _parseCategory(String slug) {
    return switch (slug) {
      'bdr' => MarketCategory.bdr,
      'etf' => MarketCategory.etf,
      'fiis' => MarketCategory.fiis,
      _ => MarketCategory.acoesBr,
    };
  }
}
