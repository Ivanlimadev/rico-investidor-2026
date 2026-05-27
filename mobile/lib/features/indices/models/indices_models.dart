import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class IndexQuoteDto {
  const IndexQuoteDto({
    required this.symbol,
    required this.name,
    required this.group,
    required this.price,
    required this.changePercent,
    this.dayHigh,
    this.dayLow,
    this.previousClose,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    this.provider = 'brapi',
  });

  final String symbol;
  final String name;
  final String group;
  final double price;
  final double changePercent;
  final double? dayHigh;
  final double? dayLow;
  final double? previousClose;
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final String provider;

  factory IndexQuoteDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return IndexQuoteDto(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      group: json['group'] as String? ?? 'brasil',
      price: (json['price'] as num).toDouble(),
      changePercent: (json['change_percent'] as num).toDouble(),
      dayHigh: numVal('day_high'),
      dayLow: numVal('day_low'),
      previousClose: numVal('previous_close'),
      fiftyTwoWeekHigh: numVal('fifty_two_week_high'),
      fiftyTwoWeekLow: numVal('fifty_two_week_low'),
      provider: json['provider'] as String? ?? 'brapi',
    );
  }

  AssetItem toAssetItem() {
    return AssetItem(
      symbol: symbol,
      name: name,
      category: MarketCategory.indices,
      price: price,
      changePercent: changePercent,
    );
  }
}

class IndexHistoryPointDto {
  const IndexHistoryPointDto({required this.date, required this.value});

  final String date;
  final double value;

  factory IndexHistoryPointDto.fromJson(Map<String, dynamic> json) {
    return IndexHistoryPointDto(
      date: json['date'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

class IndexDetailDto {
  const IndexDetailDto({
    required this.quote,
    this.history = const [],
  });

  final IndexQuoteDto quote;
  final List<IndexHistoryPointDto> history;

  factory IndexDetailDto.fromJson(Map<String, dynamic> json) {
    final quoteRaw = json['quote'] as Map<String, dynamic>? ?? json;
    final historyRaw = json['history'] as List<dynamic>? ?? const [];
    return IndexDetailDto(
      quote: IndexQuoteDto.fromJson(quoteRaw),
      history: historyRaw.map((item) => IndexHistoryPointDto.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class IndexListResponseDto {
  const IndexListResponseDto({required this.items, required this.count});

  final List<IndexQuoteDto> items;
  final int count;

  factory IndexListResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return IndexListResponseDto(
      items: raw.map((item) => IndexQuoteDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class IndexExploreResponseDto {
  const IndexExploreResponseDto({
    required this.items,
    required this.count,
    required this.total,
    required this.page,
    required this.totalPages,
    this.group = 'all',
  });

  final List<IndexQuoteDto> items;
  final int count;
  final int total;
  final int page;
  final int totalPages;
  final String group;

  factory IndexExploreResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return IndexExploreResponseDto(
      items: raw.map((item) => IndexQuoteDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      total: json['total'] as int? ?? raw.length,
      page: json['page'] as int? ?? 1,
      totalPages: json['total_pages'] as int? ?? 1,
      group: json['group'] as String? ?? 'all',
    );
  }
}

class IndexHistoryResponseDto {
  const IndexHistoryResponseDto({
    required this.symbol,
    required this.history,
    required this.count,
  });

  final String symbol;
  final List<IndexHistoryPointDto> history;
  final int count;

  factory IndexHistoryResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['history'] as List<dynamic>? ?? const [];
    return IndexHistoryResponseDto(
      symbol: json['symbol'] as String,
      history: raw.map((item) => IndexHistoryPointDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

String normalizeIndexSymbol(String raw) {
  final cleaned = raw.trim().toUpperCase();
  return switch (cleaned) {
    'IBOV' || 'BVSP' => '^BVSP',
    'SPX' || 'SP500' => '^GSPC',
    'NASDAQ' => '^IXIC',
    'DJI' || 'DOW' => '^DJI',
    _ => cleaned.startsWith('^') ? cleaned : cleaned,
  };
}

String formatIndexPoints(double value) {
  final negative = value < 0;
  final abs = value.abs();
  final decimals = abs >= 1000 ? 0 : 2;
  final fixed = abs.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integer = parts[0];
  final fraction = parts.length > 1 ? parts[1] : '';

  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    if (i > 0 && (integer.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(integer[i]);
  }

  final formatted = fraction.isEmpty ? buffer.toString() : '$buffer,$fraction';
  return negative ? '- $formatted' : formatted;
}

String indexGroupLabel(String group) {
  return switch (group) {
    'brasil' => 'Brasil',
    'fiis' => 'FIIs',
    'setorial' => 'Setorial',
    'internacional' => 'Internacional',
    _ => group,
  };
}

String indexDisplaySymbol(String symbol) {
  return switch (symbol.toUpperCase()) {
    '^BVSP' => 'IBOV',
    '^GSPC' => 'S&P 500',
    '^IXIC' => 'Nasdaq',
    '^DJI' => 'Dow Jones',
    _ => symbol.replaceAll('^', ''),
  };
}
