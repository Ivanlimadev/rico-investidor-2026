class PerformancePointDto {
  const PerformancePointDto({
    required this.tradeDate,
    required this.tickerReturnPct,
    required this.benchmarkReturnPct,
  });

  final String tradeDate;
  final double tickerReturnPct;
  final double benchmarkReturnPct;

  factory PerformancePointDto.fromJson(Map<String, dynamic> json) {
    return PerformancePointDto(
      tradeDate: json['trade_date'] as String,
      tickerReturnPct: (json['ticker_return_pct'] as num).toDouble(),
      benchmarkReturnPct: (json['benchmark_return_pct'] as num).toDouble(),
    );
  }
}

class StockPerformanceDto {
  const StockPerformanceDto({
    required this.ticker,
    required this.benchmark,
    required this.benchmarkLabel,
    required this.range,
    required this.count,
    required this.points,
    this.tickerReturnPct,
    this.benchmarkReturnPct,
    this.provider = 'brapi',
  });

  final String ticker;
  final String benchmark;
  final String benchmarkLabel;
  final String range;
  final int count;
  final double? tickerReturnPct;
  final double? benchmarkReturnPct;
  final List<PerformancePointDto> points;
  final String provider;

  factory StockPerformanceDto.fromJson(Map<String, dynamic> json) {
    final raw = json['points'] as List<dynamic>? ?? const [];
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return StockPerformanceDto(
      ticker: json['ticker'] as String,
      benchmark: json['benchmark'] as String,
      benchmarkLabel: json['benchmark_label'] as String,
      range: json['range'] as String,
      count: json['count'] as int? ?? raw.length,
      tickerReturnPct: numVal('ticker_return_pct'),
      benchmarkReturnPct: numVal('benchmark_return_pct'),
      points: raw.map((item) => PerformancePointDto.fromJson(item as Map<String, dynamic>)).toList(),
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}
