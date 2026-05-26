import 'package:flutter/material.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_theme.dart';
import 'package:rico_investidor/models/portfolio_allocation_slice.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/models/portfolio_summary.dart';
import 'package:rico_investidor/services/asset_search_service.dart';

class PortfolioState {
  PortfolioState({
    List<PortfolioHolding>? holdings,
    List<DividendPayment>? dividends,
    AssetSearchService? searchService,
  })  : holdings = List.of(holdings ?? []),
        dividends = List.of(dividends ?? []),
        searchService = searchService ?? AssetSearchService();

  final List<PortfolioHolding> holdings;
  final List<DividendPayment> dividends;
  final AssetSearchService searchService;

  int _idCounter = 0;
  String _nextId() => 'h-${++_idCounter}';
  String _nextDividendId() => 'd-${++_idCounter}';

  double get totalBalance =>
      holdings.fold(0, (sum, h) => sum + h.marketValue);

  double get monthlyDividends {
    final now = DateTime.now();
    return dividends
        .where((d) => d.date.year == now.year && d.date.month == now.month)
        .fold(0, (sum, d) => sum + d.amount);
  }

  double get previousMonthDividends {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return dividends
        .where((d) => d.date.year == prev.year && d.date.month == prev.month)
        .fold(0, (sum, d) => sum + d.amount);
  }

  PortfolioSummary buildSummary() {
    final prev = previousMonthDividends;
    final current = monthlyDividends;
    final divChange = prev == 0 ? (current > 0 ? 100.0 : 0.0) : ((current - prev) / prev) * 100;

    final invested = holdings.fold(0.0, (s, h) => s + h.invested);
    final profit = holdings.fold(0.0, (s, h) => s + h.profit);
    final portfolioChange = invested == 0 ? 0.0 : (profit / invested) * 100;

    return PortfolioSummary(
      totalBalance: totalBalance,
      monthlyDividends: monthlyDividends,
      portfolioChangePercent: portfolioChange,
      dividendsVsLastMonthPercent: divChange,
    );
  }

  List<PortfolioAllocationSlice> computeAllocation() {
    if (holdings.isEmpty) return const [];

    final totals = <MarketCategory, double>{};
    var outros = 0.0;

    for (final holding in holdings) {
      final category = searchService.categoryForSymbol(holding.symbol);
      final value = holding.marketValue;
      if (category == null) {
        outros += value;
      } else {
        totals[category] = (totals[category] ?? 0) + value;
      }
    }

    final total = totalBalance;
    if (total <= 0) return const [];

    final slices = <PortfolioAllocationSlice>[];

    for (final entry in totals.entries) {
      slices.add(
        PortfolioAllocationSlice(
          category: entry.key,
          label: entry.key.theme.shortLabel,
          value: entry.value,
          percent: (entry.value / total) * 100,
          color: entry.key.theme.glowColor,
        ),
      );
    }

    if (outros > 0) {
      slices.add(
        PortfolioAllocationSlice(
          category: null,
          label: 'Outros',
          value: outros,
          percent: (outros / total) * 100,
          color: const Color(0xFF9E9E9E),
        ),
      );
    }

    slices.sort((a, b) => b.value.compareTo(a.value));
    return slices;
  }

  void applyOpenFinanceImport(List<PortfolioHolding> imported) {
    holdings.removeWhere((h) => h.id.startsWith('of-'));
    holdings.addAll(imported);
  }

  void addHolding({
    required String symbol,
    required String name,
    required double quantity,
    required double averagePrice,
    double? currentPrice,
    DividendPayment? initialDividend,
  }) {
    final quote = searchService.findBySymbol(symbol);
    final resolvedPrice = currentPrice ?? quote?.price ?? averagePrice;

    final existingIndex = holdings.indexWhere((h) => h.symbol == symbol);
    if (existingIndex >= 0) {
      final existing = holdings[existingIndex];
      final totalQty = existing.quantity + quantity;
      final avg =
          ((existing.averagePrice * existing.quantity) + (averagePrice * quantity)) / totalQty;
      holdings[existingIndex] = existing.copyWith(
        quantity: totalQty,
        averagePrice: avg,
        currentPrice: resolvedPrice,
      );
    } else {
      holdings.add(
        PortfolioHolding(
          id: _nextId(),
          symbol: symbol,
          name: name,
          quantity: quantity,
          averagePrice: averagePrice,
          currentPrice: resolvedPrice,
        ),
      );
    }

    if (initialDividend != null) {
      dividends.add(
        DividendPayment(
          id: _nextDividendId(),
          symbol: initialDividend.symbol,
          name: initialDividend.name,
          amount: initialDividend.amount,
          date: initialDividend.date,
        ),
      );
    }
  }

  void addDividend({
    required String symbol,
    required String name,
    required double amount,
    required DateTime date,
  }) {
    dividends.add(
      DividendPayment(
        id: _nextDividendId(),
        symbol: symbol,
        name: name,
        amount: amount,
        date: date,
      ),
    );
  }

  List<DividendPayment> dividendsThisMonth() {
    final now = DateTime.now();
    return dividends
        .where((d) => d.date.year == now.year && d.date.month == now.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<DividendChartPoint> chartPoints(DividendChartGranularity granularity) {
    if (dividends.isEmpty) return const [];

    final now = DateTime.now();
    switch (granularity) {
      case DividendChartGranularity.day:
        return _aggregateDays(now, 30);
      case DividendChartGranularity.month:
        return _aggregateMonths(now, 12);
      case DividendChartGranularity.year:
        return _aggregateYears(now, 5);
    }
  }

  List<DividendChartPoint> _aggregateDays(DateTime now, int days) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final buckets = <DateTime, double>{};

    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      buckets[day] = 0;
    }

    for (final d in dividends) {
      final key = DateTime(d.date.year, d.date.month, d.date.day);
      if (!buckets.containsKey(key)) continue;
      buckets[key] = (buckets[key] ?? 0) + d.amount;
    }

    final sortedKeys = buckets.keys.toList()..sort();
    return sortedKeys
        .map(
          (key) => DividendChartPoint(
            label: '${key.day}/${key.month}',
            total: buckets[key]!,
            periodStart: key,
          ),
        )
        .toList();
  }

  List<DividendChartPoint> _aggregateMonths(DateTime now, int months) {
    final points = <DividendChartPoint>[];
    for (var i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final total = dividends
          .where((d) => d.date.year == month.year && d.date.month == month.month)
          .fold(0.0, (s, d) => s + d.amount);
      points.add(
        DividendChartPoint(
          label: _monthLabel(month.month),
          total: total,
          periodStart: month,
        ),
      );
    }
    return points;
  }

  List<DividendChartPoint> _aggregateYears(DateTime now, int years) {
    final points = <DividendChartPoint>[];
    for (var i = years - 1; i >= 0; i--) {
      final year = now.year - i;
      final total = dividends.where((d) => d.date.year == year).fold(0.0, (s, d) => s + d.amount);
      points.add(
        DividendChartPoint(
          label: '$year',
          total: total,
          periodStart: DateTime(year),
        ),
      );
    }
    return points;
  }

  String _monthLabel(int month) {
    const labels = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return labels[month - 1];
  }
}

PortfolioState createInitialPortfolioState({AssetSearchService? searchService}) {
  final now = DateTime.now();
  return PortfolioState(
    searchService: searchService,
    holdings: const [
      PortfolioHolding(
        id: 'h-1',
        symbol: 'PETR4',
        name: 'Petrobras PN',
        quantity: 100,
        averagePrice: 36.50,
        currentPrice: 38.42,
      ),
      PortfolioHolding(
        id: 'h-2',
        symbol: 'HGLG11',
        name: 'CSHG Logística',
        quantity: 30,
        averagePrice: 158.00,
        currentPrice: 162.80,
      ),
    ],
    dividends: [
      DividendPayment(
        id: 'd-1',
        symbol: 'PETR4',
        name: 'Petrobras PN',
        amount: 680,
        date: DateTime(now.year, now.month, 5),
      ),
      DividendPayment(
        id: 'd-2',
        symbol: 'HGLG11',
        name: 'CSHG Logística',
        amount: 420,
        date: DateTime(now.year, now.month, 12),
      ),
      DividendPayment(
        id: 'd-3',
        symbol: 'MXRF11',
        name: 'Maxi Renda',
        amount: 88.40,
        date: DateTime(now.year, now.month - 1, 18),
      ),
      DividendPayment(
        id: 'd-4',
        symbol: 'PETR4',
        name: 'Petrobras PN',
        amount: 650,
        date: DateTime(now.year - 1, 11, 8),
      ),
      DividendPayment(
        id: 'd-5',
        symbol: 'HGLG11',
        name: 'CSHG Logística',
        amount: 390,
        date: DateTime(now.year - 2, 6, 14),
      ),
      DividendPayment(
        id: 'd-6',
        symbol: 'VALE3',
        name: 'Vale ON',
        amount: 920,
        date: DateTime(now.year - 3, 3, 22),
      ),
    ],
  ).._idCounter = 10;
}
