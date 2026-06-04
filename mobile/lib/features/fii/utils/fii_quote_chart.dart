import 'package:rico_investidor/models/fii_models.dart';

enum FiiQuotePeriod {
  day1,
  day5,
  month1,
  month3,
  month6,
  ytd,
  year1,
  years5,
  max,
}

/// Períodos do gráfico de ações (B3 / BDR) — sem MAX (histórico completo é lento e inconsistente).
const stockQuotePeriodChoices = <FiiQuotePeriod>[
  FiiQuotePeriod.day1,
  FiiQuotePeriod.day5,
  FiiQuotePeriod.month1,
  FiiQuotePeriod.month3,
  FiiQuotePeriod.month6,
  FiiQuotePeriod.ytd,
  FiiQuotePeriod.year1,
  FiiQuotePeriod.years5,
];

enum QuoteChartStyle {
  line,
  candlestick,
}

int limitForQuotePeriod(FiiQuotePeriod period) {
  return switch (period) {
    FiiQuotePeriod.day1 || FiiQuotePeriod.day5 => 500,
    FiiQuotePeriod.month1 => 30,
    FiiQuotePeriod.month3 => 66,
    FiiQuotePeriod.month6 => 132,
    FiiQuotePeriod.ytd => 252,
    FiiQuotePeriod.year1 => 252,
    FiiQuotePeriod.years5 => 1260,
    FiiQuotePeriod.max => 5000,
  };
}

String? rangeForQuotePeriod(FiiQuotePeriod period) {
  return switch (period) {
    FiiQuotePeriod.day1 => '1d',
    FiiQuotePeriod.day5 => '5d',
    FiiQuotePeriod.month1 => '1mo',
    FiiQuotePeriod.month3 => '3mo',
    FiiQuotePeriod.month6 => '6mo',
    FiiQuotePeriod.ytd => 'ytd',
    FiiQuotePeriod.year1 => '1y',
    FiiQuotePeriod.years5 => '5y',
    FiiQuotePeriod.max => 'max',
  };
}

String intervalForQuotePeriod(FiiQuotePeriod period) {
  return switch (period) {
    FiiQuotePeriod.day1 || FiiQuotePeriod.day5 => '5m',
    _ => '1d',
  };
}

bool isIntradayQuotePeriod(FiiQuotePeriod period) {
  return switch (period) {
    FiiQuotePeriod.day1 || FiiQuotePeriod.day5 => true,
    _ => false,
  };
}

String quotePeriodLabel(FiiQuotePeriod period) {
  return switch (period) {
    FiiQuotePeriod.day1 => '1D',
    FiiQuotePeriod.day5 => '5D',
    FiiQuotePeriod.month1 => '1M',
    FiiQuotePeriod.month3 => '3M',
    FiiQuotePeriod.month6 => '6M',
    FiiQuotePeriod.ytd => 'YTD',
    FiiQuotePeriod.year1 => '1A',
    FiiQuotePeriod.years5 => '5A',
    FiiQuotePeriod.max => 'MAX',
  };
}

String quotePeriodHint(FiiQuotePeriod period) {
  return switch (period) {
    FiiQuotePeriod.day1 => 'Intraday · candles 5 min · pregão de hoje',
    FiiQuotePeriod.day5 => 'Intraday · candles 5 min · últimos 5 dias',
    FiiQuotePeriod.month1 => 'Cotação diária · último mês',
    FiiQuotePeriod.month3 => 'Cotação diária · últimos 3 meses',
    FiiQuotePeriod.month6 => 'Cotação diária · últimos 6 meses',
    FiiQuotePeriod.ytd => 'Cotação diária · ano corrente',
    FiiQuotePeriod.year1 => 'Cotação diária · último ano',
    FiiQuotePeriod.years5 => 'Cotação diária · últimos 5 anos',
    FiiQuotePeriod.max => 'Histórico completo · pregão B3',
  };
}

String quoteChartStyleLabel(QuoteChartStyle style) {
  return switch (style) {
    QuoteChartStyle.line => 'Linha',
    QuoteChartStyle.candlestick => 'Candles',
  };
}

/// Mais antigo → mais recente.
List<FiiCandleBar> sortedQuoteBars(List<FiiCandleBar> bars) {
  return List<FiiCandleBar>.from(bars)..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));
}

/// Remove pregões duplicados (mesma data), mantendo o último valor.
List<FiiCandleBar> dedupeQuoteBarsByDate(List<FiiCandleBar> bars) {
  final sorted = sortedQuoteBars(bars);
  if (sorted.isEmpty) return sorted;

  final deduped = <FiiCandleBar>[];
  for (final bar in sorted) {
    final dateKey = bar.tradeDate.contains('T') ? bar.tradeDate.split('T').first : bar.tradeDate;
    if (deduped.isEmpty) {
      deduped.add(bar);
      continue;
    }
    final prevKey = deduped.last.tradeDate.contains('T')
        ? deduped.last.tradeDate.split('T').first
        : deduped.last.tradeDate;
    if (dateKey == prevKey) {
      deduped[deduped.length - 1] = bar;
    } else {
      deduped.add(bar);
    }
  }
  return deduped;
}

/// Último pregão por data parseada (não depende só da ordenação lexicográfica).
DateTime? latestTradeDateInBars(List<FiiCandleBar> bars) {
  DateTime? latest;
  for (final bar in bars) {
    final day = parseTradeDate(bar.tradeDate);
    if (day != null && (latest == null || day.isAfter(latest))) {
      latest = day;
    }
  }
  return latest;
}

/// Janela ancorada no pregão mais recente (3M/6M são subconjuntos do histórico completo).
List<FiiCandleBar> barsForTrailingCalendarDays(
  List<FiiCandleBar> bars, {
  required int calendarDays,
}) {
  final sorted = dedupeQuoteBarsByDate(bars);
  if (sorted.isEmpty) return sorted;

  final anchor = latestTradeDateInBars(sorted);
  if (anchor == null) return sorted;

  final cutoff = anchor.subtract(Duration(days: calendarDays));
  return sorted
      .where((bar) {
        final day = parseTradeDate(bar.tradeDate);
        return day != null && !day.isBefore(cutoff);
      })
      .toList();
}

/// Últimos N pregões (mesma regra do gráfico B3) — 3M/6M/1A ficam distintos.
List<FiiCandleBar> barsForTrailingTradingDays(List<FiiCandleBar> bars, {required int maxBars}) {
  final sorted = dedupeQuoteBarsByDate(bars);
  if (sorted.length <= maxBars) return sorted;
  return sorted.sublist(sorted.length - maxBars);
}

DateTime? parseTradeDate(String raw) {
  final normalized = raw.contains('T') ? raw.split('T').first : raw;
  return DateTime.tryParse(normalized);
}

double? periodChangePct(List<FiiCandleBar> bars) {
  final sorted = sortedQuoteBars(bars);
  if (sorted.length < 2) return null;
  final first = sorted.first.close;
  final last = sorted.last.close;
  if (first == 0) return null;
  return ((last - first) / first) * 100;
}

String? dayBefore(String tradeDate) {
  final date = DateTime.tryParse(tradeDate);
  if (date == null) return null;
  final previous = date.subtract(const Duration(days: 1));
  return _formatDate(previous);
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String formatQuoteDate(String tradeDate) {
  final date = DateTime.tryParse(tradeDate);
  if (date == null) return tradeDate;
  if (tradeDate.contains('T')) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
  return formatQuoteDateTime(date);
}

String formatQuoteDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Largura do plot horizontal (pregão ≈ 3px; curto usa largura mínima legível).
double quoteChartScrollWidth(int pointCount) {
  const minWidth = 280.0;
  if (pointCount < 2) return minWidth;
  final computed = pointCount * 3.2;
  if (computed < minWidth) return minWidth;
  return computed;
}

String axisLabelForIndex(List<FiiCandleBar> sorted, int index, FiiQuotePeriod period) {
  if (index < 0 || index >= sorted.length) return '';
  final date = sorted[index].tradeDate;
  if (date.contains('T')) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    if (index != 0 && index != sorted.length - 1 && index % 12 != 0) return '';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  final parts = date.split('-');
  if (parts.length < 3) return date;

  final isLong = sorted.length > 120;
  if (isLong) {
    if (index != 0 && index != sorted.length - 1 && index % 40 != 0) return '';
    return '${parts[1]}/${parts[0].substring(2)}';
  }

  if (sorted.length > 20 && index != 0 && index != sorted.length - 1 && index % 3 != 0) {
    return '';
  }
  return '${parts[2]}/${parts[1]}';
}

double niceYInterval(double min, double max) {
  final range = (max - min).abs();
  if (range <= 0) return 1;
  if (range <= 5) return 0.5;
  if (range <= 20) return 2;
  if (range <= 50) return 5;
  if (range <= 200) return 20;
  return (range / 5).ceilToDouble();
}
