import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/simple_quote_line_chart.dart';
import 'package:rico_investidor/core/utils/quote_chart.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/global_stock_chart_prices.dart';
import 'package:rico_investidor/models/market_series_models.dart';

enum GlobalStockChartPeriod { today, months3, months6, year1, years5, max }

class GlobalStockQuoteChart extends StatefulWidget {
  const GlobalStockQuoteChart({
    super.key,
    required this.candles,
    this.intradayCandles = const [],
    this.intradayInterval = '5min',
    this.maxHistoryDays = 1260,
    this.realtimeEnabled = false,
    this.chartHeight = 220,
  });

  final List<GlobalStockCandleDto> candles;
  final List<GlobalStockCandleDto> intradayCandles;
  final String intradayInterval;
  final int maxHistoryDays;
  final bool realtimeEnabled;
  final double chartHeight;

  @override
  State<GlobalStockQuoteChart> createState() => _GlobalStockQuoteChartState();
}

class _GlobalStockQuoteChartState extends State<GlobalStockQuoteChart> {
  static const _lineBlue = Color(0xFF3B82F6);

  GlobalStockChartPeriod _period = GlobalStockChartPeriod.years5;
  int? _selectedIndex;
  bool _useAdjusted = true;

  bool get _hasAdjustedData => hasGlobalStockAdjustedChartData(widget.candles);

  bool get _hasSplitAdjustment =>
      widget.candles.any(globalStockCandleHasSplitAdjustment);

  bool get _effectiveUseAdjusted => effectiveGlobalStockChartAdjusted(
        useAdjusted: _useAdjusted,
        candles: widget.candles,
      );

  @override
  void didUpdateWidget(covariant GlobalStockQuoteChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles.length != widget.candles.length) {
      _selectedIndex = null;
    }
    if (_useAdjusted && !_hasAdjustedData) {
      _useAdjusted = false;
    }
  }

  bool get _showToday => widget.realtimeEnabled && widget.intradayCandles.length >= 2;

  List<GlobalStockCandleDto> get _sourceCandles =>
      _period == GlobalStockChartPeriod.today ? widget.intradayCandles : widget.candles;

  List<QuoteCandleBar> get _allBars => dedupeQuoteBarsByDate(_toBars(_sourceCandles));

  List<QuoteCandleBar> get _bars {
    if (_period == GlobalStockChartPeriod.today) return _allBars;
    return barsForTrailingTradingDays(_allBars, maxBars: _tradingDaysForPeriod(_period));
  }

  static int _tradingDaysFor(GlobalStockChartPeriod period, {int maxHistoryDays = 1260}) {
    return switch (period) {
      GlobalStockChartPeriod.today => 500,
      GlobalStockChartPeriod.months3 => 66,
      GlobalStockChartPeriod.months6 => 132,
      GlobalStockChartPeriod.year1 => 252,
      GlobalStockChartPeriod.years5 => 1260,
      GlobalStockChartPeriod.max => maxHistoryDays.clamp(252, 5475),
    };
  }

  int _tradingDaysForPeriod(GlobalStockChartPeriod period) =>
      _tradingDaysFor(period, maxHistoryDays: widget.maxHistoryDays);

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    final selected = _selectedIndex != null && _selectedIndex! < bars.length
        ? bars[_selectedIndex!]
        : (bars.isNotEmpty ? bars.last : null);
    final changePct = periodChangePct(bars);

    return Card(
      elevation: 0,
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Histórico', style: Theme.of(context).textTheme.titleSmall),
                      if (bars.isNotEmpty)
                        Text(
                          _period == GlobalStockChartPeriod.today
                              ? 'Intraday · ${widget.intradayInterval} · ${bars.length} barras'
                              : _effectiveUseAdjusted
                                  ? 'Fechamento diário EOD · ${bars.length} pregões · preço ajustado'
                                  : 'Fechamento diário EOD · ${bars.length} pregões · preço nominal',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                    ],
                  ),
                ),
                if (changePct != null)
                  Text(
                    '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: changePct >= 0 ? AppColors.positive : AppColors.negative,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_showToday)
                  FilterChip(
                    label: const Text('Hoje'),
                    selected: _period == GlobalStockChartPeriod.today,
                    onSelected: (_) => setState(() {
                      _period = GlobalStockChartPeriod.today;
                      _selectedIndex = null;
                    }),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
                if (_hasSplitAdjustment && _period != GlobalStockChartPeriod.today)
                  Tooltip(
                    message: _useAdjusted
                        ? 'Exibindo preços ajustados por splits'
                        : 'Exibir preços ajustados por splits',
                    child: FilterChip(
                      label: const Text('Ajustado'),
                      selected: _useAdjusted,
                      onSelected: (selected) => setState(() {
                        _useAdjusted = selected;
                        _selectedIndex = null;
                      }),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                  ),
                ...GlobalStockChartPeriod.values.where((period) {
                  if (period == GlobalStockChartPeriod.today) return false;
                  if (period == GlobalStockChartPeriod.max && widget.maxHistoryDays <= 1260) {
                    return false;
                  }
                  return true;
                }).map((period) {
                  return FilterChip(
                    label: Text(_periodLabel(period)),
                    selected: _period == period,
                    onSelected: (_) => setState(() {
                      _period = period;
                      if (period == GlobalStockChartPeriod.years5 ||
                          period == GlobalStockChartPeriod.max) {
                        _useAdjusted = true;
                      }
                      _selectedIndex = null;
                    }),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  );
                }),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              _SelectedBar(bar: selected),
            ],
            const SizedBox(height: 8),
            SimpleQuoteLineChart(
              bars: bars,
              height: widget.chartHeight,
              lineColor: _lineBlue,
              formatPrice: _formatUsd,
              formatDateLabel: _formatDateLabel,
              onSelectedIndex: (index) => setState(() => _selectedIndex = index),
            ),
          ],
        ),
      ),
    );
  }

  List<QuoteCandleBar> _toBars(List<GlobalStockCandleDto> candles) {
    return candles
        .map(
          (c) {
            final price = _chartClose(c);
            if (price <= 0) return null;
            return QuoteCandleBar(
              tradeDate: c.date,
              open: c.open ?? price,
              high: c.high ?? price,
              low: c.low ?? price,
              close: price,
              volume: c.volume,
            );
          },
        )
        .whereType<QuoteCandleBar>()
        .toList();
  }

  double _chartClose(GlobalStockCandleDto candle) =>
      chartCloseForGlobalStockCandle(candle, useAdjusted: _effectiveUseAdjusted);

  static String _periodLabel(GlobalStockChartPeriod period) {
    return switch (period) {
      GlobalStockChartPeriod.today => 'Hoje',
      GlobalStockChartPeriod.months3 => '3M',
      GlobalStockChartPeriod.months6 => '6M',
      GlobalStockChartPeriod.year1 => '1A',
      GlobalStockChartPeriod.years5 => '5A',
      GlobalStockChartPeriod.max => 'Máx',
    };
  }

  static String _formatDateLabel(String raw) {
    if (raw.length >= 10) {
      final parts = raw.substring(0, 10).split('-');
      if (parts.length == 3) {
        const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
        final date = DateTime.tryParse(raw.substring(0, 10));
        if (date != null) {
          return '${weekdays[date.weekday - 1]} ${parts[2]}';
        }
      }
      return raw.substring(5, 10).replaceAll('-', '/');
    }
    return raw;
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.bar});

  final QuoteCandleBar bar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          bar.tradeDate.length >= 10 ? bar.tradeDate.substring(0, 10) : bar.tradeDate,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatUsd(bar.close),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B82F6),
              ),
        ),
        if (bar.volume != null) ...[
          const Spacer(),
          Text(
            'Vol. ${_compactVolume(bar.volume!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  static String _compactVolume(double volume) {
    if (volume >= 1e9) return '${(volume / 1e9).toStringAsFixed(1)}B';
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(1)}M';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(1)}K';
    return volume.toStringAsFixed(0);
  }
}

String _formatUsd(double value) {
  if (value >= 1000) return '\$${value.toStringAsFixed(0)}';
  return '\$${value.toStringAsFixed(2)}';
}
