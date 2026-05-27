import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class TreasuryRateInfoDto {
  const TreasuryRateInfoDto({
    this.rateType,
    this.rateUnit,
    this.description,
  });

  final String? rateType;
  final String? rateUnit;
  final String? description;

  factory TreasuryRateInfoDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TreasuryRateInfoDto();
    return TreasuryRateInfoDto(
      rateType: json['rate_type'] as String?,
      rateUnit: json['rate_unit'] as String?,
      description: json['description'] as String?,
    );
  }
}

class TreasuryBondDto {
  const TreasuryBondDto({
    required this.symbol,
    required this.bondType,
    this.indexer,
    this.couponType,
    this.maturityDate,
    this.durationDays,
    this.baseDate,
    this.buyRate,
    this.sellRate,
    this.buyPrice,
    this.sellPrice,
    this.basePrice,
    this.rateInfo,
    this.provider = 'brapi',
  });

  final String symbol;
  final String bondType;
  final String? indexer;
  final String? couponType;
  final String? maturityDate;
  final int? durationDays;
  final String? baseDate;
  final double? buyRate;
  final double? sellRate;
  final double? buyPrice;
  final double? sellPrice;
  final double? basePrice;
  final TreasuryRateInfoDto? rateInfo;
  final String provider;

  double? get displayPrice => sellPrice ?? basePrice ?? buyPrice;

  factory TreasuryBondDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return TreasuryBondDto(
      symbol: json['symbol'] as String,
      bondType: json['bond_type'] as String,
      indexer: json['indexer'] as String?,
      couponType: json['coupon_type'] as String?,
      maturityDate: json['maturity_date'] as String?,
      durationDays: json['duration_days'] as int?,
      baseDate: json['base_date'] as String?,
      buyRate: numVal('buy_rate'),
      sellRate: numVal('sell_rate'),
      buyPrice: numVal('buy_price'),
      sellPrice: numVal('sell_price'),
      basePrice: numVal('base_price'),
      rateInfo: TreasuryRateInfoDto.fromJson(json['rate_info'] as Map<String, dynamic>?),
      provider: json['provider'] as String? ?? 'brapi',
    );
  }

  AssetItem toAssetItem() {
    return AssetItem(
      symbol: symbol,
      name: bondType,
      category: MarketCategory.tesouroDireto,
      price: displayPrice ?? 0,
      changePercent: 0,
    );
  }
}

class TreasuryHistoryPointDto {
  const TreasuryHistoryPointDto({
    required this.date,
    this.buyRate,
    this.sellRate,
    this.buyPrice,
    this.sellPrice,
    this.basePrice,
  });

  final String date;
  final double? buyRate;
  final double? sellRate;
  final double? buyPrice;
  final double? sellPrice;
  final double? basePrice;

  double? get displayPrice => sellPrice ?? basePrice ?? buyPrice;

  factory TreasuryHistoryPointDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return TreasuryHistoryPointDto(
      date: json['date'] as String,
      buyRate: numVal('buy_rate'),
      sellRate: numVal('sell_rate'),
      buyPrice: numVal('buy_price'),
      sellPrice: numVal('sell_price'),
      basePrice: numVal('base_price'),
    );
  }
}

class TreasuryDetailDto {
  const TreasuryDetailDto({
    required this.bond,
    this.history = const [],
  });

  final TreasuryBondDto bond;
  final List<TreasuryHistoryPointDto> history;
}

class TreasuryListResponseDto {
  const TreasuryListResponseDto({required this.items, required this.count});

  final List<TreasuryBondDto> items;
  final int count;

  factory TreasuryListResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return TreasuryListResponseDto(
      items: raw.map((item) => TreasuryBondDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class TreasuryExploreResponseDto {
  const TreasuryExploreResponseDto({
    required this.items,
    required this.count,
    required this.total,
    required this.page,
    required this.totalPages,
    this.group = 'all',
  });

  final List<TreasuryBondDto> items;
  final int count;
  final int total;
  final int page;
  final int totalPages;
  final String group;

  factory TreasuryExploreResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return TreasuryExploreResponseDto(
      items: raw.map((item) => TreasuryBondDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      total: json['total'] as int? ?? raw.length,
      page: json['page'] as int? ?? 1,
      totalPages: json['total_pages'] as int? ?? 1,
      group: json['group'] as String? ?? 'all',
    );
  }
}

class TreasuryHistoryResponseDto {
  const TreasuryHistoryResponseDto({
    required this.symbol,
    required this.history,
    required this.count,
    this.bondType,
    this.indexer,
    this.rateInfo,
  });

  final String symbol;
  final String? bondType;
  final String? indexer;
  final TreasuryRateInfoDto? rateInfo;
  final List<TreasuryHistoryPointDto> history;
  final int count;

  factory TreasuryHistoryResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['history'] as List<dynamic>? ?? const [];
    return TreasuryHistoryResponseDto(
      symbol: json['symbol'] as String,
      bondType: json['bond_type'] as String?,
      indexer: json['indexer'] as String?,
      rateInfo: TreasuryRateInfoDto.fromJson(json['rate_info'] as Map<String, dynamic>?),
      history: raw.map((item) => TreasuryHistoryPointDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

String normalizeTreasurySymbol(String raw) => raw.trim().toLowerCase();

String formatTreasuryRate(double? rate, {String unit = '% a.a.'}) {
  if (rate == null) return '—';
  return '${rate.toStringAsFixed(2)} $unit';
}

String treasuryIndexerLabel(String? indexer) {
  return switch (indexer) {
    'selic' => 'Selic',
    'prefixado' => 'Prefixado',
    'ipca' => 'IPCA+',
    'igpm' => 'IGP-M',
    _ => indexer ?? '—',
  };
}

String treasuryCouponLabel(String? couponType) {
  return switch (couponType) {
    'zero' => 'Sem cupom',
    'semestral' => 'Juros semestrais',
    _ => couponType ?? '—',
  };
}
