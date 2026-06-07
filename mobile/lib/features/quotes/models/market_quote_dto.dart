import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class MarketQuoteDto {
  const MarketQuoteDto({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.category,
    this.provider = 'marketstack',
    this.exchange,
    this.logoUrl,
    this.dividendYield12m,
    this.priceToBook,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.previousClose,
    this.sessionDate,
    this.splitFactor,
    this.dividendAmount,
    this.adjClose,
    this.sparkline = const [],
  });

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final String category;
  final String provider;
  final String? exchange;
  final String? logoUrl;
  final double? dividendYield12m;
  final double? priceToBook;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final double? previousClose;
  final String? sessionDate;
  final double? splitFactor;
  final double? dividendAmount;
  final double? adjClose;
  final List<double> sparkline;

  factory MarketQuoteDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    final price = numVal('price');
    if (price == null) {
      throw FormatException('Cotação sem preço para ${json['symbol']}');
    }

    return MarketQuoteDto(
      symbol: json['symbol'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : (json['symbol'] as String? ?? ''),
      price: price,
      changePercent: numVal('change_percent') ?? 0,
      category: json['category'] as String? ?? 'stocks',
      provider: json['provider'] as String? ?? 'marketstack',
      exchange: json['exchange'] as String?,
      logoUrl: json['logo_url'] as String?,
      dividendYield12m: numVal('dividend_yield_12m'),
      priceToBook: numVal('price_to_book'),
      open: numVal('open'),
      high: numVal('high'),
      low: numVal('low'),
      volume: numVal('volume'),
      previousClose: numVal('previous_close'),
      sessionDate: json['session_date'] as String?,
      splitFactor: numVal('split_factor'),
      dividendAmount: numVal('dividend_amount'),
      adjClose: numVal('adj_close'),
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
      logoUrl: logoUrl,
      dividendYield12m: dividendYield12m,
      priceToBook: priceToBook,
      exchangeMic: exchange,
      sparkline: sparkline,
    );
  }

  MarketCategory _parseCategory(String slug) {
    return switch (slug) {
      'reits' => MarketCategory.reits,
      'cripto' => MarketCategory.cripto,
      _ => MarketCategory.stocks,
    };
  }
}

class QuoteListResponse {
  const QuoteListResponse({required this.items, required this.count});

  final List<MarketQuoteDto> items;
  final int count;

  factory QuoteListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return QuoteListResponse(
      items: raw.map((e) => MarketQuoteDto.fromJson(e as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}
