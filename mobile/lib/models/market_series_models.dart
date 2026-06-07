class DistributionPayment {
  const DistributionPayment({
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

  factory DistributionPayment.fromJson(Map<String, dynamic> json) {
    return DistributionPayment(
      referenceDate: json['reference_date'] as String?,
      paymentDate: json['payment_date'] as String?,
      valuePerShare: _toDouble(json['value_per_share']),
      dyMonthPct: _toDouble(json['dy_month_pct']),
      bookValuePerShare: _toDouble(json['book_value_per_share']),
      label: json['label'] as String?,
    );
  }
}

class DistributionYear {
  const DistributionYear({
    required this.year,
    this.totalPerShare,
    this.payments,
  });

  final int year;
  final double? totalPerShare;
  final int? payments;

  factory DistributionYear.fromJson(Map<String, dynamic> json) {
    return DistributionYear(
      year: json['year'] as int,
      totalPerShare: _toDouble(json['total_per_share']),
      payments: json['payments'] as int?,
    );
  }
}

class HistoryPricePoint {
  const HistoryPricePoint({
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

  factory HistoryPricePoint.fromJson(Map<String, dynamic> json) {
    return HistoryPricePoint(
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

class QuoteCandleBar {
  const QuoteCandleBar({
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

  factory QuoteCandleBar.fromJson(Map<String, dynamic> json) {
    return QuoteCandleBar(
      tradeDate: json['trade_date'] as String,
      open: _toDouble(json['open']) ?? 0,
      high: _toDouble(json['high']) ?? 0,
      low: _toDouble(json['low']) ?? 0,
      close: _toDouble(json['close']) ?? 0,
      volume: _toDouble(json['volume']),
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
