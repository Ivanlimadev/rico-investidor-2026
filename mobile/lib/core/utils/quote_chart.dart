import 'package:rico_investidor/models/market_series_models.dart';

enum QuotePeriod {
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

const stockQuotePeriodChoices = <QuotePeriod>[
  QuotePeriod.day1,
  QuotePeriod.day5,
  QuotePeriod.month1,
  QuotePeriod.month3,
  QuotePeriod.month6,
  QuotePeriod.ytd,
  QuotePeriod.year1,
  QuotePeriod.years5,
];

enum QuoteChartStyle {
  line,
  candlestick,
}

int limitForQuotePeriod(QuotePeriod period) {
  return switch (period) {
    QuotePeriod.day1 || QuotePeriod.day5 => 500,
    QuotePeriod.month1 => 30,
    QuotePeriod.month3 => 66,
    QuotePeriod.month6 => 132,
    QuotePeriod.ytd => 252,
    QuotePeriod.year1 => 252,
    QuotePeriod.years5 => 1260,
    QuotePeriod.max => 5000,
  };
}

String? rangeForQuotePeriod(QuotePeriod period) {
  return switch (period) {
    QuotePeriod.day1 => '1d',
    QuotePeriod.day5 => '5d',
    QuotePeriod.month1 => '1mo',
    QuotePeriod.month3 => '3mo',
    QuotePeriod.month6 => '6mo',
    QuotePeriod.ytd => 'ytd',
    QuotePeriod.year1 => '1y',
    QuotePeriod.years5 => '5y',
    QuotePeriod.max => 'max',
  };
}

String intervalForQuotePeriod(QuotePeriod period) {
  return switch (period) {
    QuotePeriod.day1 || QuotePeriod.day5 => '5m',
    _ => '1d',
  };
}

bool isIntradayQuotePeriod(QuotePeriod period) {
  return switch (period) {
    QuotePeriod.day1 || QuotePeriod.day5 => true,
    _ => false,
  };
}

String quotePeriodLabel(QuotePeriod period) {
  return switch (period) {
    QuotePeriod.day1 => '1D',
    QuotePeriod.day5 => '5D',
    QuotePeriod.month1 => '1M',
    QuotePeriod.month3 => '3M',
    QuotePeriod.month6 => '6M',
    QuotePeriod.ytd => 'YTD',
    QuotePeriod.year1 => '1A',
    QuotePeriod.years5 => '5A',
    QuotePeriod.max => 'MAX',
  };
}

String quotePeriodHint(QuotePeriod period) {
  return switch (period) {
    QuotePeriod.day1 => 'Intraday · candles 5 min · pregão de hoje',
    QuotePeriod.day5 => 'Intraday · candles 5 min · últimos 5 dias',
    QuotePeriod.month1 => 'Cotação diária · último mês',
    QuotePeriod.month3 => 'Cotação diária · últimos 3 meses',
    QuotePeriod.month6 => 'Cotação diária · últimos 6 meses',
    QuotePeriod.ytd => 'Cotação diária · ano corrente',
    QuotePeriod.year1 => 'Cotação diária · último ano',
    QuotePeriod.years5 => 'Cotação diária · últimos 5 anos',
    QuotePeriod.max => 'Histórico completo',
  };
}

String quoteChartStyleLabel(QuoteChartStyle style) {
  return switch (style) {
    QuoteChartStyle.line => 'Linha',
    QuoteChartStyle.candlestick => 'Candles',
  };
}

List<QuoteCandleBar> sortedQuoteBars(List<QuoteCandleBar> bars) {
  return List<QuoteCandleBar>.from(bars)..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));
}

List<QuoteCandleBar> dedupeQuoteBarsByDate(List<QuoteCandleBar> bars) {
  final sorted = sortedQuoteBars(bars);
  if (sorted.isEmpty) return sorted;

  final deduped = <QuoteCandleBar>[];
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

DateTime? latestTradeDateInBars(List<QuoteCandleBar> bars) {
  DateTime? latest;
  for (final bar in bars) {
    final day = parseTradeDate(bar.tradeDate);
    if (day != null && (latest == null || day.isAfter(latest))) {
      latest = day;
    }
  }
  return latest;
}

List<QuoteCandleBar> barsForTrailingCalendarDays(
  List<QuoteCandleBar> bars, {
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

List<QuoteCandleBar> barsForTrailingTradingDays(List<QuoteCandleBar> bars, {required int maxBars}) {
  final sorted = dedupeQuoteBarsByDate(bars);
  if (sorted.length <= maxBars) return sorted;
  return sorted.sublist(sorted.length - maxBars);
}

DateTime? parseTradeDate(String raw) {
  final normalized = raw.contains('T') ? raw.split('T').first : raw;
  return DateTime.tryParse(normalized);
}

double? periodChangePct(List<QuoteCandleBar> bars) {
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

double quoteChartScrollWidth(int pointCount) {
  const minWidth = 280.0;
  if (pointCount < 2) return minWidth;
  final computed = pointCount * 3.2;
  if (computed < minWidth) return minWidth;
  return computed;
}

String axisLabelForIndex(List<QuoteCandleBar> sorted, int index, QuotePeriod period) {
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
