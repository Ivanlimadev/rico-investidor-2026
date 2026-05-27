import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoHistoryChart extends StatefulWidget {
  const CryptoHistoryChart({
    super.key,
    required this.symbol,
    required this.history,
    this.chartHeight = 220,
  });

  final String symbol;
  final List<CryptoHistoryPointDto> history;
  final double chartHeight;

  @override
  State<CryptoHistoryChart> createState() => _CryptoHistoryChartState();
}

class _CryptoHistoryChartState extends State<CryptoHistoryChart> {
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

    final sorted = List<CryptoHistoryPointDto>.from(widget.history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final spots = <FlSpot>[
      for (var i = 0; i < sorted.length; i++) FlSpot(i.toDouble(), sorted[i].value),
    ];

    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
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
            Text('Histórico (USD)', style: Theme.of(context).textTheme.titleSmall),
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
                    formatCryptoPrice(selected.value),
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
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes
                          .map(
                            (_) => TouchedSpotIndicatorData(
                              FlLine(color: AppColors.positive.withValues(alpha: 0.5), strokeWidth: 1),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.positive,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                            ),
                          )
                          .toList();
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
