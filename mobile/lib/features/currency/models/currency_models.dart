import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class CurrencyQuoteDto {
  const CurrencyQuoteDto({
    required this.pair,
    required this.name,
    required this.fromCurrency,
    required this.toCurrency,
    this.bidPrice,
    this.askPrice,
    this.high,
    this.low,
    this.bidVariation,
    this.changePercent,
    this.updatedAt,
    this.provider = 'brapi',
  });

  final String pair;
  final String name;
  final String fromCurrency;
  final String toCurrency;
  final double? bidPrice;
  final double? askPrice;
  final double? high;
  final double? low;
  final double? bidVariation;
  final double? changePercent;
  final String? updatedAt;
  final String provider;

  double? get midPrice {
    if (bidPrice != null && askPrice != null) {
      return (bidPrice! + askPrice!) / 2;
    }
    return bidPrice ?? askPrice;
  }

  factory CurrencyQuoteDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return CurrencyQuoteDto(
      pair: json['pair'] as String,
      name: json['name'] as String,
      fromCurrency: json['from_currency'] as String,
      toCurrency: json['to_currency'] as String,
      bidPrice: numVal('bid_price'),
      askPrice: numVal('ask_price'),
      high: numVal('high'),
      low: numVal('low'),
      bidVariation: numVal('bid_variation'),
      changePercent: numVal('change_percent'),
      updatedAt: json['updated_at'] as String?,
      provider: json['provider'] as String? ?? 'brapi',
    );
  }

  AssetItem toAssetItem() {
    return AssetItem(
      symbol: pair,
      name: name,
      category: MarketCategory.moeda,
      price: midPrice ?? 0,
      changePercent: changePercent ?? 0,
    );
  }
}

class CurrencyHistoryPointDto {
  const CurrencyHistoryPointDto({required this.date, required this.value});

  final String date;
  final double value;

  factory CurrencyHistoryPointDto.fromJson(Map<String, dynamic> json) {
    return CurrencyHistoryPointDto(
      date: json['date'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

class CurrencyDetailDto {
  const CurrencyDetailDto({
    required this.quote,
    this.history = const [],
  });

  final CurrencyQuoteDto quote;
  final List<CurrencyHistoryPointDto> history;
}

class CurrencyListResponseDto {
  const CurrencyListResponseDto({required this.items, required this.count});

  final List<CurrencyQuoteDto> items;
  final int count;

  factory CurrencyListResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return CurrencyListResponseDto(
      items: raw.map((item) => CurrencyQuoteDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class CurrencyHistoryResponseDto {
  const CurrencyHistoryResponseDto({
    required this.pair,
    required this.history,
    required this.count,
  });

  final String pair;
  final List<CurrencyHistoryPointDto> history;
  final int count;

  factory CurrencyHistoryResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['history'] as List<dynamic>? ?? const [];
    return CurrencyHistoryResponseDto(
      pair: json['pair'] as String,
      history: raw.map((item) => CurrencyHistoryPointDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class CurrencyExploreResponseDto {
  const CurrencyExploreResponseDto({
    required this.items,
    required this.count,
    required this.total,
    required this.page,
    required this.totalPages,
    this.group = 'all',
  });

  final List<CurrencyQuoteDto> items;
  final int count;
  final int total;
  final int page;
  final int totalPages;
  final String group;

  factory CurrencyExploreResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return CurrencyExploreResponseDto(
      items: raw.map((item) => CurrencyQuoteDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      total: json['total'] as int? ?? raw.length,
      page: json['page'] as int? ?? 1,
      totalPages: json['total_pages'] as int? ?? 1,
      group: json['group'] as String? ?? 'all',
    );
  }
}

String normalizeCurrencyPair(String raw) {
  return raw.trim().toUpperCase().replaceAll('/', '-');
}
