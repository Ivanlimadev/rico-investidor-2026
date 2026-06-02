import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class CryptoQuoteDto {
  const CryptoQuoteDto({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    this.currency = 'USD',
    this.change,
    this.dayHigh,
    this.dayLow,
    this.volume,
    this.marketCap,
    this.imageUrl,
    this.updatedAt,
    this.bidPrice,
    this.askPrice,
    this.spread,
    this.spreadPercent,
    this.provider = 'binance',
  });

  final String symbol;
  final String name;
  final String currency;
  final double price;
  final double changePercent;
  final double? change;
  final double? dayHigh;
  final double? dayLow;
  final double? volume;
  final double? marketCap;
  final String? imageUrl;
  final String? updatedAt;
  final double? bidPrice;
  final double? askPrice;
  final double? spread;
  final double? spreadPercent;
  final String provider;

  factory CryptoQuoteDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return CryptoQuoteDto(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      currency: json['currency'] as String? ?? 'USD',
      price: (json['price'] as num).toDouble(),
      changePercent: (json['change_percent'] as num).toDouble(),
      change: numVal('change'),
      dayHigh: numVal('day_high'),
      dayLow: numVal('day_low'),
      volume: numVal('volume'),
      marketCap: numVal('market_cap'),
      imageUrl: json['image_url'] as String?,
      updatedAt: json['updated_at'] as String?,
      bidPrice: numVal('bid_price'),
      askPrice: numVal('ask_price'),
      spread: numVal('spread'),
      spreadPercent: numVal('spread_percent'),
      provider: json['provider'] as String? ?? 'binance',
    );
  }

  AssetItem toAssetItem() {
    return AssetItem(
      symbol: symbol,
      name: name,
      category: MarketCategory.cripto,
      price: price,
      changePercent: changePercent,
      logoUrl: imageUrl,
    );
  }
}

class CryptoHistoryPointDto {
  const CryptoHistoryPointDto({required this.date, required this.value});

  final String date;
  final double value;

  factory CryptoHistoryPointDto.fromJson(Map<String, dynamic> json) {
    return CryptoHistoryPointDto(
      date: json['date'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

class CryptoCandleDto {
  const CryptoCandleDto({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  factory CryptoCandleDto.fromJson(Map<String, dynamic> json) {
    double readNum(String key) => (json[key] as num).toDouble();
    return CryptoCandleDto(
      date: json['date'] as String,
      open: readNum('open'),
      high: readNum('high'),
      low: readNum('low'),
      close: readNum('close'),
      volume: readNum('volume'),
    );
  }
}

class CryptoCandlesResponseDto {
  const CryptoCandlesResponseDto({
    required this.symbol,
    required this.interval,
    required this.candles,
    required this.count,
  });

  final String symbol;
  final String interval;
  final List<CryptoCandleDto> candles;
  final int count;

  factory CryptoCandlesResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['candles'] as List<dynamic>? ?? const [];
    return CryptoCandlesResponseDto(
      symbol: json['symbol'] as String,
      interval: json['interval'] as String? ?? '1d',
      candles: raw.map((item) => CryptoCandleDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class CryptoOrderBookLevelDto {
  const CryptoOrderBookLevelDto({required this.price, required this.quantity});

  final double price;
  final double quantity;

  factory CryptoOrderBookLevelDto.fromJson(Map<String, dynamic> json) {
    return CryptoOrderBookLevelDto(
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
    );
  }
}

class CryptoOrderBookDto {
  const CryptoOrderBookDto({required this.symbol, required this.bids, required this.asks});

  final String symbol;
  final List<CryptoOrderBookLevelDto> bids;
  final List<CryptoOrderBookLevelDto> asks;

  factory CryptoOrderBookDto.fromJson(Map<String, dynamic> json) {
    List<CryptoOrderBookLevelDto> levels(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw.map((item) => CryptoOrderBookLevelDto.fromJson(item as Map<String, dynamic>)).toList();
    }

    return CryptoOrderBookDto(
      symbol: json['symbol'] as String,
      bids: levels('bids'),
      asks: levels('asks'),
    );
  }
}

class CryptoRecentTradeDto {
  const CryptoRecentTradeDto({
    required this.id,
    required this.price,
    required this.quantity,
    required this.time,
    required this.isBuyerMaker,
  });

  final int id;
  final double price;
  final double quantity;
  final String time;
  final bool isBuyerMaker;

  factory CryptoRecentTradeDto.fromJson(Map<String, dynamic> json) {
    return CryptoRecentTradeDto(
      id: json['id'] as int,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      time: json['time'] as String,
      isBuyerMaker: json['is_buyer_maker'] as bool? ?? false,
    );
  }
}

class CryptoRecentTradesDto {
  const CryptoRecentTradesDto({required this.symbol, required this.trades, required this.count});

  final String symbol;
  final List<CryptoRecentTradeDto> trades;
  final int count;

  factory CryptoRecentTradesDto.fromJson(Map<String, dynamic> json) {
    final raw = json['trades'] as List<dynamic>? ?? const [];
    return CryptoRecentTradesDto(
      symbol: json['symbol'] as String,
      trades: raw.map((item) => CryptoRecentTradeDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class CryptoMarketSnapshotDto {
  const CryptoMarketSnapshotDto({
    required this.quote,
    required this.orderBook,
    required this.trades,
  });

  final CryptoQuoteDto quote;
  final CryptoOrderBookDto orderBook;
  final CryptoRecentTradesDto trades;

  factory CryptoMarketSnapshotDto.fromJson(Map<String, dynamic> json) {
    return CryptoMarketSnapshotDto(
      quote: CryptoQuoteDto.fromJson(json['quote'] as Map<String, dynamic>),
      orderBook: CryptoOrderBookDto.fromJson(json['order_book'] as Map<String, dynamic>),
      trades: CryptoRecentTradesDto.fromJson(json['trades'] as Map<String, dynamic>),
    );
  }
}

class CryptoDetailDto {
  const CryptoDetailDto({
    required this.quote,
    this.candles = const [],
    this.history = const [],
    this.market,
    this.profile,
  });

  final CryptoQuoteDto quote;
  final List<CryptoCandleDto> candles;
  final List<CryptoHistoryPointDto> history;
  final CryptoMarketSnapshotDto? market;
  final CryptoInvestorProfileDto? profile;
}

class CryptoPerformanceStatsDto {
  const CryptoPerformanceStatsDto({
    this.change24h,
    this.change7d,
    this.change30d,
    this.change1y,
  });

  final double? change24h;
  final double? change7d;
  final double? change30d;
  final double? change1y;

  factory CryptoPerformanceStatsDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return CryptoPerformanceStatsDto(
      change24h: numVal('change_24h'),
      change7d: numVal('change_7d'),
      change30d: numVal('change_30d'),
      change1y: numVal('change_1y'),
    );
  }
}

class CryptoFundamentalsDto {
  const CryptoFundamentalsDto({
    this.marketCap,
    this.marketCapRank,
    this.circulatingSupply,
    this.totalSupply,
    this.ath,
    this.athChangePercent,
    this.atl,
    this.categories = const [],
  });

  final double? marketCap;
  final int? marketCapRank;
  final double? circulatingSupply;
  final double? totalSupply;
  final double? ath;
  final double? athChangePercent;
  final double? atl;
  final List<String> categories;

  factory CryptoFundamentalsDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    final rawCategories = json['categories'] as List<dynamic>? ?? const [];
    return CryptoFundamentalsDto(
      marketCap: numVal('market_cap'),
      marketCapRank: json['market_cap_rank'] as int?,
      circulatingSupply: numVal('circulating_supply'),
      totalSupply: numVal('total_supply'),
      ath: numVal('ath'),
      athChangePercent: numVal('ath_change_percent'),
      atl: numVal('atl'),
      categories: rawCategories.map((item) => item.toString()).toList(),
    );
  }
}

class CryptoBrlSnapshotDto {
  const CryptoBrlSnapshotDto({this.price, this.usdtBrlRate});

  final double? price;
  final double? usdtBrlRate;

  factory CryptoBrlSnapshotDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return CryptoBrlSnapshotDto(
      price: numVal('price'),
      usdtBrlRate: numVal('usdt_brl_rate'),
    );
  }
}

class CryptoInvestorProfileDto {
  const CryptoInvestorProfileDto({
    required this.symbol,
    required this.quote,
    required this.performance,
    required this.fundamentals,
    required this.brl,
  });

  final String symbol;
  final CryptoQuoteDto quote;
  final CryptoPerformanceStatsDto performance;
  final CryptoFundamentalsDto fundamentals;
  final CryptoBrlSnapshotDto brl;

  factory CryptoInvestorProfileDto.fromJson(Map<String, dynamic> json) {
    return CryptoInvestorProfileDto(
      symbol: json['symbol'] as String,
      quote: CryptoQuoteDto.fromJson(json['quote'] as Map<String, dynamic>),
      performance: CryptoPerformanceStatsDto.fromJson(json['performance'] as Map<String, dynamic>),
      fundamentals: CryptoFundamentalsDto.fromJson(json['fundamentals'] as Map<String, dynamic>),
      brl: CryptoBrlSnapshotDto.fromJson(json['brl'] as Map<String, dynamic>),
    );
  }
}

class CryptoMacroSnapshotDto {
  const CryptoMacroSnapshotDto({
    this.btcDominance,
    this.totalMarketCapUsd,
    this.totalVolume24hUsd,
    this.fearGreedIndex,
    this.fearGreedLabel,
    this.usdtBrlRate,
  });

  final double? btcDominance;
  final double? totalMarketCapUsd;
  final double? totalVolume24hUsd;
  final int? fearGreedIndex;
  final String? fearGreedLabel;
  final double? usdtBrlRate;

  factory CryptoMacroSnapshotDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return CryptoMacroSnapshotDto(
      btcDominance: numVal('btc_dominance'),
      totalMarketCapUsd: numVal('total_market_cap_usd'),
      totalVolume24hUsd: numVal('total_volume_24h_usd'),
      fearGreedIndex: json['fear_greed_index'] as int?,
      fearGreedLabel: json['fear_greed_label'] as String?,
      usdtBrlRate: numVal('usdt_brl_rate'),
    );
  }
}

class CryptoListResponseDto {
  const CryptoListResponseDto({required this.items, required this.count});

  final List<CryptoQuoteDto> items;
  final int count;

  factory CryptoListResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return CryptoListResponseDto(
      items: raw.map((item) => CryptoQuoteDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class CryptoMoversResponseDto {
  const CryptoMoversResponseDto({
    required this.gainers,
    required this.losers,
    required this.limit,
  });

  final List<CryptoQuoteDto> gainers;
  final List<CryptoQuoteDto> losers;
  final int limit;

  factory CryptoMoversResponseDto.fromJson(Map<String, dynamic> json) {
    List<CryptoQuoteDto> quotes(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw.map((item) => CryptoQuoteDto.fromJson(item as Map<String, dynamic>)).toList();
    }

    return CryptoMoversResponseDto(
      gainers: quotes('gainers'),
      losers: quotes('losers'),
      limit: json['limit'] as int? ?? quotes('gainers').length,
    );
  }
}

class CryptoHistoryResponseDto {
  const CryptoHistoryResponseDto({
    required this.symbol,
    required this.history,
    required this.count,
  });

  final String symbol;
  final List<CryptoHistoryPointDto> history;
  final int count;

  factory CryptoHistoryResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['history'] as List<dynamic>? ?? const [];
    return CryptoHistoryResponseDto(
      symbol: json['symbol'] as String,
      history: raw.map((item) => CryptoHistoryPointDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class CryptoExploreResponseDto {
  const CryptoExploreResponseDto({
    required this.items,
    required this.count,
    required this.total,
    required this.page,
    required this.totalPages,
    this.group = 'all',
  });

  final List<CryptoQuoteDto> items;
  final int count;
  final int total;
  final int page;
  final int totalPages;
  final String group;

  factory CryptoExploreResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return CryptoExploreResponseDto(
      items: raw.map((item) => CryptoQuoteDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      total: json['total'] as int? ?? raw.length,
      page: json['page'] as int? ?? 1,
      totalPages: json['total_pages'] as int? ?? 1,
      group: json['group'] as String? ?? 'all',
    );
  }
}

String normalizeCryptoSymbol(String raw) {
  final cleaned = raw.trim().toUpperCase();
  if (cleaned.endsWith('USDT') && cleaned.length > 4) {
    return cleaned.substring(0, cleaned.length - 4);
  }
  return cleaned;
}

String formatCryptoPrice(double value, {String currency = 'USD'}) {
  final negative = value < 0;
  final abs = value.abs();
  final decimals = abs >= 1000 ? 2 : (abs >= 1 ? 2 : (abs >= 0.01 ? 4 : 6));
  final fixed = abs.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integer = parts[0];
  final fraction = parts.length > 1 ? parts[1] : '';

  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    if (i > 0 && (integer.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(integer[i]);
  }

  final amount = fraction.isEmpty ? buffer.toString() : '$buffer.$fraction';
  final prefix = currency == 'USD'
      ? '\$'
      : currency == 'BRL'
          ? 'R\$'
          : currency;
  final formatted = '$prefix$amount';
  return negative ? '-$formatted' : formatted;
}

String formatCryptoVolume(double value, {String currency = 'USD'}) {
  final abs = value.abs();
  final prefix = value < 0 ? '-' : '';
  final symbol = currency == 'USD' ? '\$' : currency;
  if (abs >= 1e12) return '$prefix$symbol${(abs / 1e12).toStringAsFixed(1)}T';
  if (abs >= 1e9) return '$prefix$symbol${(abs / 1e9).toStringAsFixed(1)}B';
  if (abs >= 1e6) return '$prefix$symbol${(abs / 1e6).toStringAsFixed(1)}M';
  return formatCryptoPrice(value, currency: currency);
}
