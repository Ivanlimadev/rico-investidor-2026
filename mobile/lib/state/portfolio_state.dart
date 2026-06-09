import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:rico_investidor/core/markets/market_visibility.dart';
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

  /// Nova referência para forçar rebuild após mutação in-place dos holdings.
  PortfolioState cloneForUi() => PortfolioState(
        holdings: List.of(holdings),
        dividends: dividends,
        searchService: searchService,
        usdBrlRate: usdBrlRate,
      );

  /// Corrige moeda persistida errada (ex.: ação B3 salva como US$).
  static List<PortfolioHolding> repairHoldingsCurrencies(
    List<PortfolioHolding> holdings, {
    required AssetSearchService searchService,
  }) {
    return holdings.map((holding) {
      final inferred = searchService.categoryForSymbol(holding.symbol);
      final category = resolveMarketCategory(
        symbol: holding.symbol,
        stored: holding.category,
        inferred: inferred,
      );
      final correct = resolvedHoldingCurrency(
        holding.copyWith(category: category),
        category: category,
      );
      final needsCurrency = holding.currency != correct;
      final needsCategory = holding.category != category;
      if (!needsCurrency && !needsCategory) return holding;
      return holding.copyWith(
        currency: correct,
        category: category,
      );
    }).toList();
  }

  static const _uuid = Uuid();
  String _nextId() => _uuid.v4();
  String _nextDividendId() => _uuid.v4();

  MarketCategory? categoryForHolding(PortfolioHolding holding) {
    return resolveMarketCategory(
      symbol: holding.symbol,
      stored: holding.category,
      inferred: searchService.categoryForSymbol(holding.symbol),
    );
  }

  PortfolioBalanceBreakdown computeBalanceBreakdown() => computePortfolioBalanceBreakdown(
        holdings: holdings,
        categoryResolver: categoryForHolding,
        usdBrlRate: usdBrlRate,
      );

  /// Patrimônio total em US$.
  double totalBalanceFor(MarketPreference preference) => patrimonioTotalUsd;

  double allocationTotalFor(MarketPreference preference) =>
      computeBalanceBreakdown().allocationTotal(
        holdings,
        preference: preference,
        categoryResolver: categoryForHolding,
      );

  /// Legado — total em reais. Evite em UI; prefira [patrimonioTotalUsd].
  double get patrimonioTotalBrl => computeBalanceBreakdown().totalBrl;

  /// Patrimônio total da carteira em dólares.
  double get patrimonioTotalUsd => computeBalanceBreakdown().totalUsd;

  double get totalBalance => patrimonioTotalUsd;

  double _dividendInCurrency(DividendPayment payment, HoldingCurrency target) =>
      dividendAmountInCurrency(
        payment,
        target: target,
        usdBrlRate: usdBrlRate,
      );

  /// Total de proventos do mês (pagamento ou data com) em reais.
  double get monthlyDividendsTotalBrl => dividendsThisMonthDetailed().fold(
        0.0,
        (sum, payment) => sum + _dividendInCurrency(payment, HoldingCurrency.brl),
      );

  /// Proventos do mês só de ativos internacionais, em US$.
  double get monthlyDividendsInternationalUsd => dividendsThisMonthDetailed()
      .where(_isInternationalDividend)
      .fold(0.0, (sum, payment) => sum + payment.amount);

  double monthlyDividendsFor(MarketPreference preference) {
    return dividendsThisMonthDetailed().fold(
      0.0,
      (sum, payment) => sum + _dividendInCurrency(payment, HoldingCurrency.usd),
    );
  }

  double previousMonthDividendsTotalBrl() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return dividends
        .where(
          (d) =>
              _inCurrentMonth(d.date, prev) ||
              (d.comDate != null && _inCurrentMonth(d.comDate!, prev)),
        )
        .fold(0.0, (sum, d) => sum + _dividendInCurrency(d, HoldingCurrency.brl));
  }

  double previousMonthDividendsFor(MarketPreference preference) {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return dividends
        .where(
          (d) =>
              _inCurrentMonth(d.date, prev) ||
              (d.comDate != null && _inCurrentMonth(d.comDate!, prev)),
        )
        .fold(0.0, (sum, d) => sum + _dividendInCurrency(d, HoldingCurrency.usd));
  }

  bool _isInternationalDividend(DividendPayment payment) {
    for (final holding in holdings) {
      if (holding.symbol != payment.symbol) continue;
      return isInternationalUsdHolding(holding, category: categoryForHolding(holding));
    }
    return holdingCurrencyForSymbol(payment.symbol) == HoldingCurrency.usd;
  }

  PortfolioSummary buildSummary(MarketPreference preference) {
    final breakdown = computeBalanceBreakdown();
    final prev = previousMonthDividendsFor(preference);
    final current = monthlyDividendsFor(preference);
    final divChange = prev == 0 ? (current > 0 ? 100.0 : 0.0) : ((current - prev) / prev) * 100;

    return PortfolioSummary(
      totalBalance: breakdown.totalUsd,
      monthlyDividends: current,
      portfolioChangePercent: breakdown.combinedProfitPercent,
      dividendsVsLastMonthPercent: divChange,
      displayCurrency: HoldingCurrency.usd,
    );
  }

  List<PortfolioAllocationSlice> computeAllocation(MarketPreference preference) {
    if (holdings.isEmpty) return const [];

    final breakdown = computeBalanceBreakdown();
    final totals = <MarketCategory, double>{};
    var outros = 0.0;

    for (final holding in holdings) {
      final category = categoryForHolding(holding);
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

    final total = breakdown.allocationTotal(
      holdings,
      preference: preference,
      categoryResolver: categoryForHolding,
    );
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
    final resolvedCategory = resolveMarketCategory(
      symbol: symbol,
      stored: category,
      inferred: searchService.categoryForSymbol(symbol),
    );
    final resolvedCurrency = currency ?? holdingCurrencyForCategory(resolvedCategory);

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
        currency: resolvedCurrency,
        category: resolvedCategory,
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
          category: resolvedCategory,
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

  /// Proventos com pagamento ou data com no mês corrente (inclui previstos).
  List<DividendPayment> dividendsThisMonthDetailed() {
    final now = DateTime.now();
    return dividends
        .where((d) => _inCurrentMonth(d.date, now) || (d.comDate != null && _inCurrentMonth(d.comDate!, now)))
        .toList()
      ..sort((a, b) {
        final aKey = a.comDate ?? a.date;
        final bKey = b.comDate ?? b.date;
        return aKey.compareTo(bKey);
      });
  }

  static bool _inCurrentMonth(DateTime date, DateTime now) =>
      date.year == now.year && date.month == now.month;

  /// Gráfico Mês — total de proventos em cada mês do ano corrente.
  List<DividendChartPoint> chartPointsFor(
    DividendChartGranularity granularity,
    MarketPreference preference,
  ) {
    final target = HoldingCurrency.usd;
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
    holdings: const [],
    dividends: const [],
  );
}
