import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/models/market_series_models.dart';

/// Gráfico de linha minimalista (estilo Twelve Data): sem eixo Y, curva suave, destaque no último ponto.
class SimpleQuoteLineChart extends StatelessWidget {
  const SimpleQuoteLineChart({
    super.key,
    required this.bars,
    required this.height,
    this.lineColor,
    this.formatPrice = _defaultFormatPrice,
    this.formatDateLabel = _defaultDateLabel,
    this.onSelectedIndex,
  });

  final List<QuoteCandleBar> bars;
  final double height;
  final Color? lineColor;
  final String Function(double value) formatPrice;
  final String Function(String tradeDate) formatDateLabel;
  final ValueChanged<int>? onSelectedIndex;

  static const Color defaultLineColor = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    if (bars.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Histórico insuficiente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final color = lineColor ?? defaultLineColor;
    final spots = [for (var i = 0; i < bars.length; i++) FlSpot(i.toDouble(), bars[i].close)];
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY).abs() * 0.12).clamp(0.5, double.infinity);
    final yMin = minY - padding;
    final yMax = maxY + padding;
    final lastX = (bars.length - 1).toDouble();
    final labelStep = (bars.length / 3).ceil().clamp(1, bars.length);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax,
          minX: 0,
          maxX: lastX,
          clipData: const FlClipData.none(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                  if (i != 0 && i != bars.length - 1 && i % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatDateLabel(bars[i].tradeDate),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              VerticalLine(
                x: lastX,
                color: color.withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions ||
                  response?.lineBarSpots == null ||
                  response!.lineBarSpots!.isEmpty) {
                return;
              }
              onSelectedIndex?.call(response.lineBarSpots!.first.x.toInt());
            },
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(color: color.withValues(alpha: 0.25), strokeWidth: 1),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, dotIndex) => FlDotCirclePainter(
                      radius: 4,
                      color: color,
                      strokeWidth: 2,
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
              isCurved: true,
              curveSmoothness: 0.28,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (index != spots.length - 1) {
                    return FlDotCirclePainter(
                      radius: 0,
                      color: Colors.transparent,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 5,
                    color: color,
                    strokeWidth: 2.5,
                    strokeColor: Theme.of(context).colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.22),
                    color.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }

  static String _defaultFormatPrice(double value) {
    if (value >= 1000) return '\$${value.toStringAsFixed(0)}';
    return '\$${value.toStringAsFixed(2)}';
  }

  static String _defaultDateLabel(String raw) {
    if (raw.length >= 10) return raw.substring(5, 10).replaceAll('-', '/');
    return raw;
  }
}
