import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/portfolio_balance.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_theme.dart';
import 'package:rico_investidor/models/portfolio_allocation_slice.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/models/portfolio_summary.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

class PortfolioState {
  PortfolioState({
    List<PortfolioHolding>? holdings,
    List<DividendPayment>? dividends,
    AssetSearchService? searchService,
    this.usdBrlRate,
  })  : holdings = List.of(holdings ?? []),
        dividends = List.of(dividends ?? []),
        searchService = searchService ?? AssetSearchService();

  final List<PortfolioHolding> holdings;
  final List<DividendPayment> dividends;
  final AssetSearchService searchService;
  double? usdBrlRate;

  int _idCounter = 0;
  String _nextId() => 'h-${++_idCounter}';
  String _nextDividendId() => 'd-${++_idCounter}';

  PortfolioBalanceBreakdown computeBalanceBreakdown() => computePortfolioBalanceBreakdown(
        holdings: holdings,
        categoryResolver: searchService.categoryForSymbol,
        usdBrlRate: usdBrlRate,
      );

  /// Patrimônio na moeda preferida do usuário (BR → R$, US → US$).
  double totalBalanceFor(MarketPreference preference) =>
      computeBalanceBreakdown().primaryTotal(preference);

  /// Legado — total em US$. Prefira [totalBalanceFor].
  double get totalBalance => computeBalanceBreakdown().totalUsd;

  double _dividendInCurrency(DividendPayment payment, HoldingCurrency target) =>
      dividendAmountInCurrency(
        payment,
        target: target,
        usdBrlRate: usdBrlRate,
      );

  double monthlyDividendsFor(MarketPreference preference) {
    final target = preference.isBrazil ? HoldingCurrency.brl : HoldingCurrency.usd;
    final now = DateTime.now();
    return dividends
        .where((d) => d.date.year == now.year && d.date.month == now.month)
        .fold(0.0, (sum, d) => sum + _dividendInCurrency(d, target));
  }

  double previousMonthDividendsFor(MarketPreference preference) {
    final target = preference.isBrazil ? HoldingCurrency.brl : HoldingCurrency.usd;
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return dividends
        .where((d) => d.date.year == prev.year && d.date.month == prev.month)
        .fold(0.0, (sum, d) => sum + _dividendInCurrency(d, target));
  }

  PortfolioSummary buildSummary(MarketPreference preference) {
    final breakdown = computeBalanceBreakdown();
    final prev = previousMonthDividendsFor(preference);
    final current = monthlyDividendsFor(preference);
    final divChange = prev == 0 ? (current > 0 ? 100.0 : 0.0) : ((current - prev) / prev) * 100;

    return PortfolioSummary(
      totalBalance: breakdown.primaryTotal(preference),
      monthlyDividends: current,
      portfolioChangePercent: breakdown.primaryProfitPercent(preference),
      dividendsVsLastMonthPercent: divChange,
      displayCurrency: preference.isBrazil ? HoldingCurrency.brl : HoldingCurrency.usd,
    );
  }

  List<PortfolioAllocationSlice> computeAllocation(MarketPreference preference) {
    if (holdings.isEmpty) return const [];

    final breakdown = computeBalanceBreakdown();
    final totals = <MarketCategory, double>{};
    var outros = 0.0;

    for (final holding in holdings) {
      final category = searchService.categoryForSymbol(holding.symbol);
      final value = breakdown.allocationWeight(
        holding,
        preference: preference,
        category: category,
      );
      if (category == null) {
        outros += value;
      } else {
        totals[category] = (totals[category] ?? 0) + value;
      }
    }

    final total = breakdown.primaryTotal(preference);
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

  void addHolding({
    required String symbol,
    required String name,
    required double quantity,
    required double averagePrice,
    double? currentPrice,
    double? changePercent,
    HoldingCurrency? currency,
    MarketCategory? category,
    DividendPayment? initialDividend,
  }) {
    final resolvedPrice = currentPrice ?? averagePrice;
    final resolvedChange = changePercent ?? 0;
    final resolvedCurrency = currency ??
        (category != null ? holdingCurrencyForCategory(category) : holdingCurrencyForSymbol(symbol));

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
        changePercent: resolvedChange,
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
          changePercent: resolvedChange,
          currency: resolvedCurrency,
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

  void removeHolding(String id) {
    final index = holdings.indexWhere((h) => h.id == id);
    if (index < 0) return;

    final symbol = holdings[index].symbol.toUpperCase();
    holdings.removeAt(index);
    dividends.removeWhere((d) => d.symbol.toUpperCase() == symbol);
  }

  void applyOpenFinanceImport(List<PortfolioHolding> imported) {
    holdings.removeWhere((h) => h.id.startsWith('of-'));
    holdings.addAll(imported);
  }

  void replaceDividends(List<DividendPayment> next) {
    dividends
      ..clear()
      ..addAll(next);
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

  /// Gráfico Mês — total de proventos em cada mês do ano corrente.
  List<DividendChartPoint> chartPointsFor(
    DividendChartGranularity granularity,
    MarketPreference preference,
  ) {
    final target = preference.isBrazil ? HoldingCurrency.brl : HoldingCurrency.usd;
    final now = DateTime.now();
    return switch (granularity) {
      DividendChartGranularity.month => _aggregateMonthsOfYear(now, target),
      DividendChartGranularity.year =>
        dividends.isEmpty ? const [] : _aggregateYears(now, 5, target),
    };
  }

  List<DividendChartPoint> _aggregateMonthsOfYear(DateTime now, HoldingCurrency target) {
    return [
      for (var month = 1; month <= 12; month++)
        DividendChartPoint(
          label: _monthShortLabel(month),
          total: dividends
              .where((d) => d.date.year == now.year && d.date.month == month)
              .fold(0.0, (sum, d) => sum + _dividendInCurrency(d, target)),
          periodStart: DateTime(now.year, month),
        ),
    ];
  }

  static String _monthShortLabel(int month) {
    const labels = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return labels[month - 1];
  }

  List<DividendChartPoint> _aggregateYears(DateTime now, int years, HoldingCurrency target) {
    final points = <DividendChartPoint>[];
    for (var i = years - 1; i >= 0; i--) {
      final year = now.year - i;
      final total = dividends
          .where((d) => d.date.year == year)
          .fold(0.0, (s, d) => s + _dividendInCurrency(d, target));
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
}

PortfolioState createInitialPortfolioState({AssetSearchService? searchService}) {
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
        currency: HoldingCurrency.brl,
      ),
      PortfolioHolding(
        id: 'h-2',
        symbol: 'HGLG11',
        name: 'CSHG Logística',
        quantity: 30,
        averagePrice: 158.00,
        currentPrice: 162.80,
        currency: HoldingCurrency.brl,
      ),
    ],
    dividends: const [],
  ).._idCounter = 2;
}
