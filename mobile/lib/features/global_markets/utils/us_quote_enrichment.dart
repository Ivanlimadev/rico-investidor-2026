import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

/// Enriquece detalhe lite (só cotação + candles) com stats e rentabilidade reais.
class UsQuoteEnrichment {
  UsQuoteEnrichment._();

  static const _returnSessions = <String, int>{
    '1M': 21,
    '3M': 63,
    '1A': 252,
    '2A': 504,
    '3A': 756,
    '5A': 1260,
  };

  static MarketQuoteDto reconcileQuote(MarketQuoteDto quote, List<GlobalStockCandleDto> candles) {
    if (candles.isEmpty) return quote;
    final sorted = List<GlobalStockCandleDto>.from(candles)..sort((a, b) => a.date.compareTo(b.date));
    final last = sorted.last;
    final price = last.close;
    if (price <= 0) return quote;

    double? previousClose = quote.previousClose;
    if (sorted.length >= 2) {
      previousClose = sorted[sorted.length - 2].close;
    }
    final changePercent = previousClose != null && previousClose > 0
        ? ((price - previousClose) / previousClose) * 100
        : quote.changePercent;

    return MarketQuoteDto(
      symbol: quote.symbol,
      name: quote.name,
      price: price,
      changePercent: double.parse(changePercent.toStringAsFixed(2)),
      category: quote.category,
      provider: quote.provider,
      exchange: quote.exchange,
      logoUrl: quote.logoUrl,
      open: last.open ?? quote.open,
      high: last.high ?? quote.high,
      low: last.low ?? quote.low,
      volume: last.volume ?? quote.volume,
      previousClose: previousClose,
      sessionDate: last.date.length >= 10 ? last.date.substring(0, 10) : last.date,
      adjClose: last.adjClose ?? quote.adjClose,
      sparkline: quote.sparkline,
    );
  }

  static StockMarketStatsDto marketStatsFrom(MarketQuoteDto quote, List<GlobalStockCandleDto> candles) {
    if (candles.isEmpty) {
      return StockMarketStatsDto(
        open: quote.open,
        dayHigh: quote.high,
        dayLow: quote.low,
        previousClose: quote.previousClose,
        volume: quote.volume,
      );
    }

    final sorted = List<GlobalStockCandleDto>.from(candles)..sort((a, b) => a.date.compareTo(b.date));
    final window = sorted.length > 252 ? sorted.sublist(sorted.length - 252) : sorted;

    double? weekHigh;
    double? weekLow;
    if (window.length >= 5) {
      for (final c in window) {
        final high = c.high ?? c.close;
        final low = c.low ?? c.close;
        weekHigh = weekHigh == null ? high : (high > weekHigh! ? high : weekHigh);
        weekLow = weekLow == null ? low : (low < weekLow! ? low : weekLow);
      }
    }

    final volTail = sorted.length > 20 ? sorted.sublist(sorted.length - 20) : sorted;
    final volumes = volTail.map((c) => c.volume).whereType<double>().where((v) => v > 0).toList();
    final avgVol = volumes.isEmpty
        ? null
        : volumes.reduce((a, b) => a + b) / volumes.length;

    final sessions = window.length;
    final rangeLabel = sessions >= 200 ? '52 semanas' : (sessions >= 5 ? 'Últimos $sessions pregões' : null);

    return StockMarketStatsDto(
      open: quote.open,
      dayHigh: quote.high,
      dayLow: quote.low,
      previousClose: quote.previousClose,
      volume: quote.volume,
      avgDailyVolume: avgVol,
      fiftyTwoWeekHigh: weekHigh,
      fiftyTwoWeekLow: weekLow,
      fiftyTwoWeekRange: weekHigh != null && weekLow != null
          ? '${weekLow!.toStringAsFixed(2)} - ${weekHigh!.toStringAsFixed(2)}'
          : null,
      priceRangeSessions: sessions >= 5 ? sessions : null,
      priceRangeLabel: rangeLabel,
    );
  }

  static List<GlobalStockReturnPeriodDto> returnsFrom(
    List<GlobalStockCandleDto> candles, {
    required double currentPrice,
  }) {
    if (candles.length < 2 || currentPrice <= 0) return const [];

    final sorted = List<GlobalStockCandleDto>.from(candles)..sort((a, b) => a.date.compareTo(b.date));
    final rows = <GlobalStockReturnPeriodDto>[];

    for (final entry in _returnSessions.entries) {
      final back = entry.value;
      if (sorted.length <= back) continue;
      final start = sorted[sorted.length - 1 - back].close;
      if (start <= 0) continue;
      final pct = ((currentPrice - start) / start) * 100;
      rows.add(
        GlobalStockReturnPeriodDto(
          label: entry.key,
          monthsBack: (back / 21).round().clamp(1, 60),
          returnPct: double.parse(pct.toStringAsFixed(2)),
        ),
      );
    }
    return rows;
  }
}
