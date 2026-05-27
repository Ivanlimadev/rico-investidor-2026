import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_candlestick_chart.dart';
import 'package:rico_investidor/features/quotes/models/stock_performance.dart';
import 'package:rico_investidor/models/fii_models.dart';

class StockQuoteLineChart extends StatefulWidget {
  const StockQuoteLineChart({
    super.key,
    required this.ticker,
    required this.repository,
    this.chartHeight = 240,
    this.initialPeriod = FiiQuotePeriod.year1,
    this.initialStyle = QuoteChartStyle.line,
    this.showBenchmarkCompare = true,
    this.onPeriodChanged,
    this.onStyleChanged,
  });

  final String ticker;
  final QuoteRepository repository;
  final double chartHeight;
  final FiiQuotePeriod initialPeriod;
  final QuoteChartStyle initialStyle;
  final bool showBenchmarkCompare;
  final ValueChanged<FiiQuotePeriod>? onPeriodChanged;
  final ValueChanged<QuoteChartStyle>? onStyleChanged;

  @override
  State<StockQuoteLineChart> createState() => _StockQuoteLineChartState();
}

class _StockQuoteLineChartState extends State<StockQuoteLineChart> {
  late FiiQuotePeriod _period = widget.initialPeriod;
  late QuoteChartStyle _style = widget.initialStyle;
  List<FiiCandleBar> _bars = const [];
  StockPerformanceDto? _performance;
  bool _compareWithBenchmark = false;
  int? _selectedIndex;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPeriod();
  }

  Future<void> _loadPeriod() async {
    setState(() {
      _loading = true;
      _error = null;
      _bars = const [];
      _performance = null;
      _selectedIndex = null;
    });

    try {
      if (_compareWithBenchmark) {
        final performance = await widget.repository.getStockPerformance(
          widget.ticker,
          period: _period,
        );
        if (!mounted) return;

        setState(() {
          _performance = performance;
          _loading = false;
          _selectedIndex = performance.points.isEmpty ? null : performance.points.length - 1;
        });
        return;
      }

      final candles = await widget.repository.getStockCandles(widget.ticker, period: _period);
      if (!mounted) return;

      final sorted = sortedQuoteBars(candles);
      setState(() {
        _bars = sorted;
        _loading = false;
        _selectedIndex = sorted.isEmpty ? null : sorted.length - 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _onCompareToggled(bool enabled) {
    if (_compareWithBenchmark == enabled) return;
    if (enabled && _style == QuoteChartStyle.candlestick) {
      setState(() => _style = QuoteChartStyle.line);
      widget.onStyleChanged?.call(QuoteChartStyle.line);
    }
    setState(() => _compareWithBenchmark = enabled);
    _loadPeriod();
  }

  void _onPeriodSelected(FiiQuotePeriod period) {
    if (_period == period) return;
    if (isIntradayQuotePeriod(period) && _compareWithBenchmark) {
      _compareWithBenchmark = false;
    }
    setState(() => _period = period);
    widget.onPeriodChanged?.call(period);
    _loadPeriod();
  }

  void _onStyleSelected(QuoteChartStyle style) {
    if (_style == style) return;
    setState(() => _style = style);
    widget.onStyleChanged?.call(style);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = sortedQuoteBars(_bars);
    final performancePoints = _performance?.points ?? const [];
    final changePct = _compareWithBenchmark
        ? _performance?.tickerReturnPct
        : periodChangePct(_bars);
    final selectedBar = _selectedIndex != null && _selectedIndex! < sorted.length
        ? sorted[_selectedIndex!]
        : (sorted.isNotEmpty ? sorted.last : null);
    final selectedPerformance = _selectedIndex != null && _selectedIndex! < performancePoints.length
        ? performancePoints[_selectedIndex!]
        : (performancePoints.isNotEmpty ? performancePoints.last : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SegmentedButton<QuoteChartStyle>(
              segments: const [
                ButtonSegment(
                  value: QuoteChartStyle.line,
                  label: Text('Linha'),
                  icon: Icon(Icons.show_chart, size: 18),
                ),
                ButtonSegment(
                  value: QuoteChartStyle.candlestick,
                  label: Text('Candles'),
                  icon: Icon(Icons.candlestick_chart, size: 18),
                ),
              ],
              selected: {_style},
              onSelectionChanged: (values) => _onStyleSelected(values.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...FiiQuotePeriod.values.map((period) {
              return FilterChip(
                label: Text(quotePeriodLabel(period)),
                selected: _period == period,
                onSelected: (_) => _onPeriodSelected(period),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              );
            }),
            if (widget.showBenchmarkCompare && !isIntradayQuotePeriod(_period))
              FilterChip(
                label: const Text('vs IBOV'),
                selected: _compareWithBenchmark,
                onSelected: _onCompareToggled,
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _compareWithBenchmark
                    ? 'Retorno acumulado vs ${ _performance?.benchmarkLabel ?? 'IBOV' }'
                    : quotePeriodHint(_period),
                style: Theme.of(context).textTheme.bodySmall,
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
        if (_compareWithBenchmark && _performance != null) ...[
          const SizedBox(height: 6),
          _PerformanceLegend(performance: _performance!),
        ],
        const SizedBox(height: 8),
        if (_compareWithBenchmark && selectedPerformance != null)
          _SelectedPerformancePoint(
            point: selectedPerformance,
            ticker: widget.ticker,
            benchmarkLabel: _performance?.benchmarkLabel ?? 'IBOV',
          )
        else if (selectedBar != null)
          _style == QuoteChartStyle.candlestick
              ? StockSelectedCandleBar(bar: selectedBar)
              : _SelectedQuoteBar(bar: selectedBar),
        const SizedBox(height: 8),
        SizedBox(
          height: widget.chartHeight,
          child: _compareWithBenchmark
              ? _buildCompareChart(context, performancePoints)
              : _buildChart(context, sorted),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, List<FiiCandleBar> sorted) {
    if (_loading) {
      return _frame(context, child: const Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return _frame(
        context,
        child: Center(
          child: Text(
            'Não foi possível carregar o gráfico.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    if (sorted.length < 2) {
      return _frame(
        context,
        child: Center(
          child: Text(
            'Histórico insuficiente para o gráfico.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (_style == QuoteChartStyle.candlestick) {
      return _frame(
        context,
        child: StockCandlestickChart(
          bars: sorted,
          period: _period,
          selectedIndex: _selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
        ),
      );
    }

    return _frame(context, child: _buildLineChart(context, sorted));
  }

  Widget _buildLineChart(BuildContext context, List<FiiCandleBar> sorted) {
    final spots = [
      for (var i = 0; i < sorted.length; i++) FlSpot(i.toDouble(), sorted[i].close),
    ];

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY).abs() * 0.08).clamp(0.2, double.infinity);
    final yMin = minY - padding;
    final yMax = maxY + padding;
    final yInterval = niceYInterval(yMin, yMax);
    final lineColor = Theme.of(context).colorScheme.primary;
    final scrollWidth = quoteChartScrollWidth(sorted.length);

    final chart = LineChart(
      LineChartData(
        minY: yMin,
        maxY: yMax,
        minX: 0,
        maxX: (sorted.length - 1).toDouble(),
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
            left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if ((value - meta.min).abs() < 0.001 || (value - meta.max).abs() < 0.001) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _formatAxisPrice(value),
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final label = axisLabelForIndex(sorted, i, _period);
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response?.lineBarSpots == null ||
                response!.lineBarSpots!.isEmpty) {
              return;
            }
            final index = response.lineBarSpots!.first.x.toInt();
            if (_selectedIndex != index) {
              setState(() => _selectedIndex = index);
            }
          },
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(color: lineColor.withValues(alpha: 0.35), strokeWidth: 1),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, dotIndex) => FlDotCirclePainter(
                    radius: 3,
                    color: lineColor,
                    strokeWidth: 1,
                    strokeColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );

    if (scrollWidth > 0) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: scrollWidth, height: double.infinity, child: chart),
      );
    }
    return chart;
  }

  Widget _buildCompareChart(BuildContext context, List<PerformancePointDto> points) {
    if (_loading) {
      return _frame(context, child: const Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return _frame(
        context,
        child: Center(
          child: Text(
            'Não foi possível carregar a comparação.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    if (points.length < 2) {
      return _frame(
        context,
        child: Center(
          child: Text(
            'Histórico insuficiente para comparar com o índice.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final tickerSpots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].tickerReturnPct),
    ];
    final benchmarkSpots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].benchmarkReturnPct),
    ];

    final allValues = [
      ...tickerSpots.map((spot) => spot.y),
      ...benchmarkSpots.map((spot) => spot.y),
    ];
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY).abs() * 0.08).clamp(0.5, double.infinity);
    final yMin = minY - padding;
    final yMax = maxY + padding;
    final yInterval = niceYInterval(yMin, yMax);
    final tickerColor = Theme.of(context).colorScheme.primary;
    final benchmarkColor = AppColors.positive;
    final scrollWidth = quoteChartScrollWidth(points.length);

    final chart = LineChart(
      LineChartData(
        minY: yMin,
        maxY: yMax,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
            left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if ((value - meta.min).abs() < 0.001 || (value - meta.max).abs() < 0.001) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${value.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final label = _performanceAxisLabel(points, i);
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response?.lineBarSpots == null ||
                response!.lineBarSpots!.isEmpty) {
              return;
            }
            final index = response.lineBarSpots!.first.x.toInt();
            if (_selectedIndex != index) {
              setState(() => _selectedIndex = index);
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: tickerSpots,
            isCurved: false,
            barWidth: 2,
            color: tickerColor,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: benchmarkSpots,
            isCurved: false,
            barWidth: 2,
            color: benchmarkColor,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
      duration: Duration.zero,
    );

    final framed = _frame(
      context,
      child: scrollWidth > 0
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: scrollWidth, height: double.infinity, child: chart),
            )
          : chart,
    );
    return framed;
  }

  String _performanceAxisLabel(List<PerformancePointDto> points, int index) {
    final pseudoBars = points
        .map((point) => FiiCandleBar(tradeDate: point.tradeDate, open: 0, high: 0, low: 0, close: 0))
        .toList();
    return axisLabelForIndex(pseudoBars, index, _period);
  }

  Widget _frame(BuildContext context, {required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }

  String _formatAxisPrice(double value) {
    if (value >= 1000) return value.toStringAsFixed(0);
    if (value >= 100) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }
}

class _SelectedQuoteBar extends StatelessWidget {
  const _SelectedQuoteBar({required this.bar});

  final FiiCandleBar bar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(formatQuoteDate(bar.tradeDate), style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        Text(formatBrl(bar.close), style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _SelectedPerformancePoint extends StatelessWidget {
  const _SelectedPerformancePoint({
    required this.point,
    required this.ticker,
    required this.benchmarkLabel,
  });

  final PerformancePointDto point;
  final String ticker;
  final String benchmarkLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(formatQuoteDate(point.tradeDate), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '$ticker ${ _formatPct(point.tickerReturnPct) }',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '$benchmarkLabel ${ _formatPct(point.benchmarkReturnPct) }',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.positive),
            ),
          ],
        ),
      ],
    );
  }

  String _formatPct(double value) {
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }
}

class _PerformanceLegend extends StatelessWidget {
  const _PerformanceLegend({required this.performance});

  final StockPerformanceDto performance;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _LegendItem(
          color: Theme.of(context).colorScheme.primary,
          label: '${performance.ticker} ${_formatPct(performance.tickerReturnPct)}',
        ),
        _LegendItem(
          color: AppColors.positive,
          label: '${performance.benchmarkLabel} ${_formatPct(performance.benchmarkReturnPct)}',
        ),
      ],
    );
  }

  String _formatPct(double? value) {
    if (value == null) return '—';
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
