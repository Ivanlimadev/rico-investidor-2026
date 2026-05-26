class FiiSummary {
  const FiiSummary({
    required this.ticker,
    required this.name,
    this.segment,
    this.managementType,
    this.totalShareholders,
    this.provider = 'bolsai',
  });

  final String ticker;
  final String name;
  final String? segment;
  final String? managementType;
  final int? totalShareholders;
  final String provider;

  factory FiiSummary.fromJson(Map<String, dynamic> json) {
    return FiiSummary(
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      segment: json['segment'] as String?,
      managementType: json['management_type'] as String?,
      totalShareholders: json['total_shareholders'] as int?,
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiListResponse {
  const FiiListResponse({
    required this.count,
    required this.total,
    required this.fiis,
    this.provider = 'bolsai',
  });

  final int count;
  final int total;
  final List<FiiSummary> fiis;
  final String provider;

  factory FiiListResponse.fromJson(Map<String, dynamic> json) {
    final items = json['fiis'] as List<dynamic>? ?? [];
    return FiiListResponse(
      count: json['count'] as int? ?? items.length,
      total: json['total'] as int? ?? items.length,
      fiis: items.map((e) => FiiSummary.fromJson(e as Map<String, dynamic>)).toList(),
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiAssetComposition {
  const FiiAssetComposition({
    this.realEstateLeasedPct,
    this.realEstateUnderConstructionPct,
    this.realEstateForSalePct,
    this.landPct,
    this.otherRealEstatePct,
    this.criPct,
    this.lciPct,
    this.cepacPct,
    this.debenturesPct,
    this.fiiHoldingsPct,
    this.fipFdicPct,
    this.stocksPct,
    this.cashPct,
    this.otherPct,
  });

  final double? realEstateLeasedPct;
  final double? realEstateUnderConstructionPct;
  final double? realEstateForSalePct;
  final double? landPct;
  final double? otherRealEstatePct;
  final double? criPct;
  final double? lciPct;
  final double? cepacPct;
  final double? debenturesPct;
  final double? fiiHoldingsPct;
  final double? fipFdicPct;
  final double? stocksPct;
  final double? cashPct;
  final double? otherPct;

  factory FiiAssetComposition.fromJson(Map<String, dynamic> json) {
    return FiiAssetComposition(
      realEstateLeasedPct: _toDouble(json['real_estate_leased_pct']),
      realEstateUnderConstructionPct: _toDouble(json['real_estate_under_construction_pct']),
      realEstateForSalePct: _toDouble(json['real_estate_for_sale_pct']),
      landPct: _toDouble(json['land_pct']),
      otherRealEstatePct: _toDouble(json['other_real_estate_pct']),
      criPct: _toDouble(json['cri_pct']),
      lciPct: _toDouble(json['lci_pct']),
      cepacPct: _toDouble(json['cepac_pct']),
      debenturesPct: _toDouble(json['debentures_pct']),
      fiiHoldingsPct: _toDouble(json['fii_holdings_pct']),
      fipFdicPct: _toDouble(json['fip_fdic_pct']),
      stocksPct: _toDouble(json['stocks_pct']),
      cashPct: _toDouble(json['cash_pct']),
      otherPct: _toDouble(json['other_pct']),
    );
  }

  List<({String label, double value})> nonZeroItems() {
    final candidates = <({String label, double? value})>[
      (label: 'Imóveis locados', value: realEstateLeasedPct),
      (label: 'Em construção', value: realEstateUnderConstructionPct),
      (label: 'À venda', value: realEstateForSalePct),
      (label: 'Terrenos', value: landPct),
      (label: 'Outros imóveis', value: otherRealEstatePct),
      (label: 'CRI', value: criPct),
      (label: 'LCI', value: lciPct),
      (label: 'CEPAC', value: cepacPct),
      (label: 'Debêntures', value: debenturesPct),
      (label: 'Cotas de FIIs', value: fiiHoldingsPct),
      (label: 'FIP/FDIC', value: fipFdicPct),
      (label: 'Ações', value: stocksPct),
      (label: 'Caixa', value: cashPct),
      (label: 'Outros', value: otherPct),
    ];
    final items = <({String label, double value})>[];
    for (final item in candidates) {
      final value = item.value;
      if (value != null && value > 0) {
        items.add((label: item.label, value: value));
      }
    }
    items.sort((a, b) => b.value.compareTo(a.value));
    return items;
  }
}

class FiiFeesPaid {
  const FiiFeesPaid({this.admin, this.performance});

  final double? admin;
  final double? performance;

  factory FiiFeesPaid.fromJson(Map<String, dynamic> json) {
    return FiiFeesPaid(
      admin: _toDouble(json['admin']),
      performance: _toDouble(json['performance']),
    );
  }
}

class FiiProperty {
  const FiiProperty({
    required this.name,
    this.address,
    this.assetClass,
    this.areaSqm,
    this.revenuePct,
    this.vacancyPct,
    this.leasedPct,
  });

  final String name;
  final String? address;
  final String? assetClass;
  final double? areaSqm;
  final double? revenuePct;
  final double? vacancyPct;
  final double? leasedPct;

  factory FiiProperty.fromJson(Map<String, dynamic> json) {
    return FiiProperty(
      name: json['name'] as String,
      address: json['address'] as String?,
      assetClass: json['asset_class'] as String?,
      areaSqm: _toDouble(json['area_sqm']),
      revenuePct: _toDouble(json['revenue_pct']),
      vacancyPct: _toDouble(json['vacancy_pct']),
      leasedPct: _toDouble(json['leased_pct']),
    );
  }
}

class FiiDetail {
  const FiiDetail({
    required this.ticker,
    required this.name,
    this.referenceDate,
    this.closePrice,
    this.bookValuePerShare,
    this.pvp,
    this.dividendYieldTtm,
    this.netAssetValue,
    this.sharesOutstanding,
    this.totalShareholders,
    this.segment,
    this.managementType,
    this.administrator,
    this.administratorCnpj,
    this.mandate,
    this.inceptionDate,
    this.durationType,
    this.targetInvestors,
    this.website,
    this.email,
    this.fundType,
    this.assetComposition,
    this.feesPaidLastMonth,
    this.propertyCount,
    this.totalAreaSqm,
    this.vacancyPct,
    this.delinquencyPct,
    this.leasedPct,
    this.topProperties = const [],
    this.propertyReferenceDate,
    this.provider = 'bolsai',
  });

  final String ticker;
  final String name;
  final String? referenceDate;
  final double? closePrice;
  final double? bookValuePerShare;
  final double? pvp;
  final double? dividendYieldTtm;
  final double? netAssetValue;
  final double? sharesOutstanding;
  final int? totalShareholders;
  final String? segment;
  final String? managementType;
  final String? administrator;
  final String? administratorCnpj;
  final String? mandate;
  final String? inceptionDate;
  final String? durationType;
  final String? targetInvestors;
  final String? website;
  final String? email;
  final String? fundType;
  final FiiAssetComposition? assetComposition;
  final FiiFeesPaid? feesPaidLastMonth;
  final int? propertyCount;
  final double? totalAreaSqm;
  final double? vacancyPct;
  final double? delinquencyPct;
  final double? leasedPct;
  final List<FiiProperty> topProperties;
  final String? propertyReferenceDate;
  final String provider;

  factory FiiDetail.fromJson(Map<String, dynamic> json) {
    final properties = json['top_properties'] as List<dynamic>? ?? [];
    return FiiDetail(
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      referenceDate: json['reference_date'] as String?,
      closePrice: _toDouble(json['close_price']),
      bookValuePerShare: _toDouble(json['book_value_per_share']),
      pvp: _toDouble(json['pvp']),
      dividendYieldTtm: _toDouble(json['dividend_yield_ttm']),
      netAssetValue: _toDouble(json['net_asset_value']),
      sharesOutstanding: _toDouble(json['shares_outstanding']),
      totalShareholders: json['total_shareholders'] as int?,
      segment: json['segment'] as String?,
      managementType: json['management_type'] as String?,
      administrator: json['administrator'] as String?,
      administratorCnpj: json['administrator_cnpj'] as String?,
      mandate: json['mandate'] as String?,
      inceptionDate: json['inception_date'] as String?,
      durationType: json['duration_type'] as String?,
      targetInvestors: json['target_investors'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      fundType: json['fund_type'] as String?,
      assetComposition: json['asset_composition'] is Map<String, dynamic>
          ? FiiAssetComposition.fromJson(json['asset_composition'] as Map<String, dynamic>)
          : null,
      feesPaidLastMonth: json['fees_paid_last_month'] is Map<String, dynamic>
          ? FiiFeesPaid.fromJson(json['fees_paid_last_month'] as Map<String, dynamic>)
          : null,
      propertyCount: json['property_count'] as int?,
      totalAreaSqm: _toDouble(json['total_area_sqm']),
      vacancyPct: _toDouble(json['vacancy_pct']),
      delinquencyPct: _toDouble(json['delinquency_pct']),
      leasedPct: _toDouble(json['leased_pct']),
      topProperties: properties
          .map((e) => FiiProperty.fromJson(e as Map<String, dynamic>))
          .toList(),
      propertyReferenceDate: json['property_reference_date'] as String?,
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiDistributionPayment {
  const FiiDistributionPayment({
    this.referenceDate,
    this.paymentDate,
    this.valuePerShare,
    this.dyMonthPct,
    this.bookValuePerShare,
    this.label,
  });

  final String? referenceDate;
  final String? paymentDate;
  final double? valuePerShare;
  final double? dyMonthPct;
  final double? bookValuePerShare;
  final String? label;

  factory FiiDistributionPayment.fromJson(Map<String, dynamic> json) {
    return FiiDistributionPayment(
      referenceDate: json['reference_date'] as String?,
      paymentDate: json['payment_date'] as String?,
      valuePerShare: _toDouble(json['value_per_share']),
      dyMonthPct: _toDouble(json['dy_month_pct']),
      bookValuePerShare: _toDouble(json['book_value_per_share']),
      label: json['label'] as String?,
    );
  }
}

class FiiDistributionYear {
  const FiiDistributionYear({
    required this.year,
    this.totalPerShare,
    this.payments,
  });

  final int year;
  final double? totalPerShare;
  final int? payments;

  factory FiiDistributionYear.fromJson(Map<String, dynamic> json) {
    return FiiDistributionYear(
      year: json['year'] as int,
      totalPerShare: _toDouble(json['total_per_share']),
      payments: json['payments'] as int?,
    );
  }
}

class FiiSearchResponse {
  const FiiSearchResponse({
    required this.query,
    required this.count,
    required this.total,
    required this.fiis,
    this.provider = 'bolsai',
  });

  final String query;
  final int count;
  final int total;
  final List<FiiSummary> fiis;
  final String provider;

  factory FiiSearchResponse.fromJson(Map<String, dynamic> json) {
    final items = json['fiis'] as List<dynamic>? ?? [];
    return FiiSearchResponse(
      query: json['query'] as String? ?? '',
      count: json['count'] as int? ?? items.length,
      total: json['total'] as int? ?? items.length,
      fiis: items.map((e) => FiiSummary.fromJson(e as Map<String, dynamic>)).toList(),
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiCountResponse {
  const FiiCountResponse({required this.total, this.provider = 'bolsai'});

  final int total;
  final String provider;

  factory FiiCountResponse.fromJson(Map<String, dynamic> json) {
    return FiiCountResponse(
      total: json['total'] as int? ?? 0,
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiHistoryPoint {
  const FiiHistoryPoint({
    this.referenceDate,
    this.closePrice,
    this.bookValuePerShare,
    this.pvp,
    this.dyMonthPct,
    this.valuePerShare,
    this.netAssetValue,
    this.totalShareholders,
  });

  final String? referenceDate;
  final double? closePrice;
  final double? bookValuePerShare;
  final double? pvp;
  final double? dyMonthPct;
  final double? valuePerShare;
  final double? netAssetValue;
  final int? totalShareholders;

  factory FiiHistoryPoint.fromJson(Map<String, dynamic> json) {
    return FiiHistoryPoint(
      referenceDate: json['reference_date'] as String?,
      closePrice: _toDouble(json['close_price']),
      bookValuePerShare: _toDouble(json['book_value_per_share']),
      pvp: _toDouble(json['pvp']),
      dyMonthPct: _toDouble(json['dy_month_pct']),
      valuePerShare: _toDouble(json['value_per_share']),
      netAssetValue: _toDouble(json['net_asset_value']),
      totalShareholders: json['total_shareholders'] as int?,
    );
  }
}

class FiiHistoryResponse {
  const FiiHistoryResponse({
    required this.ticker,
    required this.name,
    required this.count,
    required this.history,
    this.provider = 'bolsai',
  });

  final String ticker;
  final String name;
  final int count;
  final List<FiiHistoryPoint> history;
  final String provider;

  factory FiiHistoryResponse.fromJson(Map<String, dynamic> json) {
    final items = json['history'] as List<dynamic>? ?? [];
    return FiiHistoryResponse(
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      count: json['count'] as int? ?? items.length,
      history: items.map((e) => FiiHistoryPoint.fromJson(e as Map<String, dynamic>)).toList(),
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiCandleBar {
  const FiiCandleBar({
    required this.tradeDate,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  final String tradeDate;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  factory FiiCandleBar.fromJson(Map<String, dynamic> json) {
    return FiiCandleBar(
      tradeDate: json['trade_date'] as String,
      open: _toDouble(json['open']) ?? 0,
      high: _toDouble(json['high']) ?? 0,
      low: _toDouble(json['low']) ?? 0,
      close: _toDouble(json['close']) ?? 0,
      volume: _toDouble(json['volume']),
    );
  }
}

class FiiCandlesResponse {
  const FiiCandlesResponse({
    required this.ticker,
    required this.count,
    required this.candles,
    this.provider = 'bolsai',
  });

  final String ticker;
  final int count;
  final List<FiiCandleBar> candles;
  final String provider;

  factory FiiCandlesResponse.fromJson(Map<String, dynamic> json) {
    final items = json['candles'] as List<dynamic>? ?? [];
    return FiiCandlesResponse(
      ticker: json['ticker'] as String,
      count: json['count'] as int? ?? items.length,
      candles: items.map((e) => FiiCandleBar.fromJson(e as Map<String, dynamic>)).toList(),
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiTenantSector {
  const FiiTenantSector({required this.sector, this.revenuePct});

  final String sector;
  final double? revenuePct;

  factory FiiTenantSector.fromJson(Map<String, dynamic> json) {
    return FiiTenantSector(
      sector: json['sector'] as String,
      revenuePct: _toDouble(json['revenue_pct']),
    );
  }
}

class FiiTenantsResponse {
  const FiiTenantsResponse({
    required this.ticker,
    this.referenceDate,
    this.count,
    this.topSectorPct,
    this.sectors = const [],
    this.provider = 'bolsai',
  });

  final String ticker;
  final String? referenceDate;
  final int? count;
  final double? topSectorPct;
  final List<FiiTenantSector> sectors;
  final String provider;

  factory FiiTenantsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['sectors'] as List<dynamic>? ?? [];
    return FiiTenantsResponse(
      ticker: json['ticker'] as String,
      referenceDate: json['reference_date'] as String?,
      count: json['count'] as int?,
      topSectorPct: _toDouble(json['top_sector_pct']),
      sectors: items.map((e) => FiiTenantSector.fromJson(e as Map<String, dynamic>)).toList(),
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiScreenerItem {
  const FiiScreenerItem({
    required this.ticker,
    required this.name,
    this.segment,
    this.managementType,
    this.mandate,
    this.administratorName,
    this.fundType,
    this.referenceDate,
    this.closePrice,
    this.bookValuePerShare,
    this.netAssetValue,
    this.sharesOutstanding,
    this.totalShareholders,
    this.pvp,
    this.dividendYieldTtm,
    this.dyMonthPct,
    this.vacancyPct,
    this.delinquencyPct,
    this.leasedPct,
    this.propertyCount,
    this.totalAreaSqm,
    this.provider = 'bolsai',
  });

  final String ticker;
  final String name;
  final String? segment;
  final String? managementType;
  final String? mandate;
  final String? administratorName;
  final String? fundType;
  final String? referenceDate;
  final double? closePrice;
  final double? bookValuePerShare;
  final double? netAssetValue;
  final double? sharesOutstanding;
  final int? totalShareholders;
  final double? pvp;
  final double? dividendYieldTtm;
  final double? dyMonthPct;
  final double? vacancyPct;
  final double? delinquencyPct;
  final double? leasedPct;
  final int? propertyCount;
  final double? totalAreaSqm;
  final String provider;

  factory FiiScreenerItem.fromJson(Map<String, dynamic> json) {
    return FiiScreenerItem(
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      segment: json['segment'] as String?,
      managementType: json['management_type'] as String?,
      mandate: json['mandate'] as String?,
      administratorName: json['administrator_name'] as String?,
      fundType: json['fund_type'] as String?,
      referenceDate: json['reference_date'] as String?,
      closePrice: _toDouble(json['close_price']),
      bookValuePerShare: _toDouble(json['book_value_per_share']),
      netAssetValue: _toDouble(json['net_asset_value']),
      sharesOutstanding: _toDouble(json['shares_outstanding']),
      totalShareholders: json['total_shareholders'] as int?,
      pvp: _toDouble(json['pvp']),
      dividendYieldTtm: _toDouble(json['dividend_yield_ttm']),
      dyMonthPct: _toDouble(json['dy_month_pct']),
      vacancyPct: _toDouble(json['vacancy_pct']),
      delinquencyPct: _toDouble(json['delinquency_pct']),
      leasedPct: _toDouble(json['leased_pct']),
      propertyCount: json['property_count'] as int?,
      totalAreaSqm: _toDouble(json['total_area_sqm']),
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiScreenerResponse {
  const FiiScreenerResponse({
    required this.data,
    required this.count,
    required this.total,
    required this.offset,
    required this.limit,
    this.provider = 'bolsai',
  });

  final List<FiiScreenerItem> data;
  final int count;
  final int total;
  final int offset;
  final int limit;
  final String provider;

  factory FiiScreenerResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];
    return FiiScreenerResponse(
      data: items.map((e) => FiiScreenerItem.fromJson(e as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? items.length,
      total: json['total'] as int? ?? items.length,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? items.length,
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

class FiiDistributions {
  const FiiDistributions({
    required this.ticker,
    required this.name,
    this.dividendYieldTtm,
    this.ttmPerShare,
    this.closePrice,
    this.totalPayments,
    this.annualSummary = const [],
    this.payments = const [],
    this.provider = 'bolsai',
  });

  final String ticker;
  final String name;
  final double? dividendYieldTtm;
  final double? ttmPerShare;
  final double? closePrice;
  final int? totalPayments;
  final List<FiiDistributionYear> annualSummary;
  final List<FiiDistributionPayment> payments;
  final String provider;

  factory FiiDistributions.fromJson(Map<String, dynamic> json) {
    final summary = json['annual_summary'] as List<dynamic>? ?? [];
    final payments = json['payments'] as List<dynamic>? ?? [];
    return FiiDistributions(
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      dividendYieldTtm: _toDouble(json['dividend_yield_ttm']),
      ttmPerShare: _toDouble(json['ttm_per_share']),
      closePrice: _toDouble(json['close_price']),
      totalPayments: json['total_payments'] as int?,
      annualSummary: summary
          .map((e) => FiiDistributionYear.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: payments
          .map((e) => FiiDistributionPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      provider: json['provider'] as String? ?? 'bolsai',
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
