import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';

class IndexHistoryChart extends StatefulWidget {
  const IndexHistoryChart({
    super.key,
    required this.history,
    this.chartHeight = 220,
  });

  final List<IndexHistoryPointDto> history;
  final double chartHeight;

  @override
  State<IndexHistoryChart> createState() => _IndexHistoryChartState();
}

class _IndexHistoryChartState extends State<IndexHistoryChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Histórico indisponível.', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    final sorted = List<IndexHistoryPointDto>.from(widget.history)..sort((a, b) => a.date.compareTo(b.date));
    final spots = <FlSpot>[
      for (var i = 0; i < sorted.length; i++) FlSpot(i.toDouble(), sorted[i].value),
    ];

    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.08;

    final selected = _selectedIndex != null && _selectedIndex! < sorted.length ? sorted[_selectedIndex!] : sorted.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Histórico de pontos', style: Theme.of(context).textTheme.titleSmall),
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
                    formatIndexPoints(selected.value),
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
                  minY: minY - padding,
                  maxY: maxY + padding,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
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
                          response?.lineBarSpots == null ||
                          response!.lineBarSpots!.isEmpty) {
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
