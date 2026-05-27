import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_fundamental_history.dart';
import 'package:rico_investidor/features/quotes/models/stock_financials.dart';

class StockFundamentalHistoryCard extends StatefulWidget {
  const StockFundamentalHistoryCard({
    super.key,
    required this.ticker,
    required this.repository,
  });

  final String ticker;
  final QuoteRepository repository;

  @override
  State<StockFundamentalHistoryCard> createState() => _StockFundamentalHistoryCardState();
}

class _StockFundamentalHistoryCardState extends State<StockFundamentalHistoryCard> {
  late Future<StockFundamentalHistoryDto> _loadFuture;
  String _metric = 'revenue';

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.repository.getFundamentalHistory(widget.ticker);
  }

  double? _metricValue(FundamentalHistoryPeriodDto period) {
    return switch (_metric) {
      'roe' => period.returnOnEquity,
      'dy' => period.dividendYield12m,
      'pe' => period.priceEarnings,
      _ => period.totalRevenue,
    };
  }

  String _formatMetric(double? value) {
    if (value == null) return '—';
    return switch (_metric) {
      'roe' || 'dy' => '${value.toStringAsFixed(1)}%',
      'pe' => value.toStringAsFixed(2),
      _ => formatFinancialValue(value),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StockFundamentalHistoryDto>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final periods = List<FundamentalHistoryPeriodDto>.from(snapshot.data!.periods)
          ..sort((a, b) => a.endDate.compareTo(b.endDate));
        final points = periods
            .map((period) => MapEntry(period, _metricValue(period)))
            .where((entry) => entry.value != null)
            .toList();

        if (points.length < 2) return const SizedBox.shrink();

        final maxY = points.map((entry) => entry.value!).reduce((a, b) => a > b ? a : b);
        final minY = points.map((entry) => entry.value!).reduce((a, b) => a < b ? a : b);
        final padding = (maxY - minY).abs() * 0.15 + 1;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Evolução trimestral', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(id: 'revenue', label: 'Receita'),
                    _buildMetricChip(id: 'roe', label: 'ROE'),
                    _buildMetricChip(id: 'dy', label: 'DY 12m'),
                    _buildMetricChip(id: 'pe', label: 'P/L'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minY: minY - padding,
                      maxY: maxY + padding,
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (points.length / 4).ceilToDouble().clamp(1, 999),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  formatFundamentalPeriodLabel(points[index].key.endDate),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].value!),
                          ],
                          isCurved: true,
                          color: AppColors.positive,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.positive.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Último: ${_formatMetric(points.last.value)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricChip({required String id, required String label}) {
    return ChoiceChip(
      label: Text(label),
      selected: _metric == id,
      onSelected: (_) => setState(() => _metric = id),
    );
  }
}
