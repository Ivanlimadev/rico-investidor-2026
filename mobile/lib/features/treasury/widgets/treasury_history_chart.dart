import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/treasury/models/treasury_models.dart';

class TreasuryHistoryChart extends StatefulWidget {
  const TreasuryHistoryChart({
    super.key,
    required this.history,
    this.chartHeight = 220,
  });

  final List<TreasuryHistoryPointDto> history;
  final double chartHeight;

  @override
  State<TreasuryHistoryChart> createState() => _TreasuryHistoryChartState();
}

class _TreasuryHistoryChartState extends State<TreasuryHistoryChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Histórico indisponível.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final sorted = List<TreasuryHistoryPointDto>.from(widget.history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final values = sorted.map((point) => point.displayPrice ?? 0).toList();
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.08;
    final chartMinY = minY - padding;
    final chartMaxY = maxY + padding;

    final selected = _selectedIndex != null && _selectedIndex! < sorted.length
        ? sorted[_selectedIndex!]
        : sorted.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Preço unitário (PU)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(selected.date, style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  Text(
                    selected.displayPrice != null ? formatBrl(selected.displayPrice!) : '—',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: widget.chartHeight,
              child: LineChart(
                LineChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (chartMaxY - chartMinY) / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.lineBarSpots == null ||
                          response.lineBarSpots!.isEmpty) {
                        return;
                      }
                      setState(() => _selectedIndex = response.lineBarSpots!.first.x.toInt());
                    },
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.positive,
                      barWidth: 2.5,
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
          ],
        ),
      ),
    );
  }
}
