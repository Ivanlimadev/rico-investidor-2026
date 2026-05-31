import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/fii_models.dart';

enum GlobalStockChartPeriod { months3, months6, year1, all }

class GlobalStockQuoteChart extends StatefulWidget {
  const GlobalStockQuoteChart({
    super.key,
    required this.candles,
    this.chartHeight = 240,
  });

  final List<GlobalStockCandleDto> candles;
  final double chartHeight;

  @override
  State<GlobalStockQuoteChart> createState() => _GlobalStockQuoteChartState();
}

class _GlobalStockQuoteChartState extends State<GlobalStockQuoteChart> {
  GlobalStockChartPeriod _period = GlobalStockChartPeriod.year1;
  int? _selectedIndex;
  bool _useAdjusted = false;

  List<FiiCandleBar> get _bars {
    final all = sortedQuoteBars(_toBars(widget.candles));
    final limit = switch (_period) {
      GlobalStockChartPeriod.months3 => 66,
      GlobalStockChartPeriod.months6 => 132,
      GlobalStockChartPeriod.year1 => 252,
      GlobalStockChartPeriod.all => all.length,
    };
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    final selected = _selectedIndex != null && _selectedIndex! < bars.length
        ? bars[_selectedIndex!]
        : (bars.isNotEmpty ? bars.last : null);
    final changePct = periodChangePct(bars);

    return Card(
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Histórico de cotação', style: Theme.of(context).textTheme.titleSmall),
            Text(
              _useAdjusted ? 'Fechamento ajustado (splits/dividendos) · USD' : 'Fechamento diário (EOD) · USD',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: const Text('Ajustado'),
                  selected: _useAdjusted,
                  onSelected: (selected) => setState(() {
                    _useAdjusted = selected;
                    _selectedIndex = null;
                  }),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                ),
                ...GlobalStockChartPeriod.values.map((period) {
                return FilterChip(
                  label: Text(_periodLabel(period)),
                  selected: _period == period,
                  onSelected: (_) => setState(() {
                    _period = period;
                    _selectedIndex = null;
                  }),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                );
                }).toList(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _periodHint(_period),
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
            if (selected != null) ...[
              const SizedBox(height: 8),
              _SelectedBar(bar: selected),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: widget.chartHeight,
              child: _buildChart(context, bars),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<FiiCandleBar> bars) {
    if (bars.length < 2) {
      return Center(
        child: Text(
          'Histórico insuficiente para o gráfico.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final spots = [for (var i = 0; i < bars.length; i++) FlSpot(i.toDouble(), bars[i].close)];
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY).abs() * 0.08).clamp(0.2, double.infinity);
    final yMin = minY - padding;
    final yMax = maxY + padding;
    final yInterval = niceYInterval(yMin, yMax);
    final lineColor = Theme.of(context).colorScheme.primary;
    final scrollWidth = quoteChartScrollWidth(bars.length);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: scrollWidth,
            height: widget.chartHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
              child: LineChart(
                LineChartData(
                  minY: yMin,
                  maxY: yMax,
                  minX: 0,
                  maxX: (bars.length - 1).toDouble(),
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
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          if ((value - meta.min).abs() < 0.001 || (value - meta.max).abs() < 0.001) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _formatUsd(value),
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
                        interval: (bars.length / 4).clamp(1, 999).toDouble(),
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                          if (i != 0 && i != bars.length - 1 && i % ((bars.length / 4).ceil()) != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _formatDateLabel(bars[i].tradeDate),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions || response?.lineBarSpots == null) return;
                      final spot = response!.lineBarSpots!.first;
                      setState(() => _selectedIndex = spot.x.toInt());
                    },
                    handleBuiltInTouches: true,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<FiiCandleBar> _toBars(List<GlobalStockCandleDto> candles) {
    return candles
        .map(
          (c) {
            final price = _useAdjusted ? c.chartClose : c.close;
            return FiiCandleBar(
              tradeDate: c.date,
              open: c.open ?? price,
              high: c.high ?? price,
              low: c.low ?? price,
              close: price,
              volume: c.volume,
            );
          },
        )
        .toList();
  }

  static String _periodLabel(GlobalStockChartPeriod period) {
    return switch (period) {
      GlobalStockChartPeriod.months3 => '3M',
      GlobalStockChartPeriod.months6 => '6M',
      GlobalStockChartPeriod.year1 => '1A',
      GlobalStockChartPeriod.all => 'Máx',
    };
  }

  static String _periodHint(GlobalStockChartPeriod period) {
    return switch (period) {
      GlobalStockChartPeriod.months3 => 'Últimos ~3 meses',
      GlobalStockChartPeriod.months6 => 'Últimos ~6 meses',
      GlobalStockChartPeriod.year1 => 'Último ano',
      GlobalStockChartPeriod.all => 'Todo o histórico carregado',
    };
  }

  static String _formatDateLabel(String raw) {
    if (raw.length >= 10) return raw.substring(5, 10).replaceAll('-', '/');
    return raw;
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.bar});

  final FiiCandleBar bar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          bar.tradeDate.length >= 10 ? bar.tradeDate.substring(0, 10) : bar.tradeDate,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: 12),
        Text(
          _formatUsd(bar.close),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
