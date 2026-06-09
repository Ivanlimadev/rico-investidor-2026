import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/models/dividend_payment.dart';

class DividendPeriodChart extends StatelessWidget {
  const DividendPeriodChart({
    super.key,
    required this.points,
  });

  final List<DividendChartPoint> points;

  static const _bottomReserved = 28.0;
  static const _labelHeadroom = 28.0;
  static const _chartHeight = 248.0;
  static const _horizontalPadding = 4.0;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Sem proventos neste período',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final maxY = points.map((p) => p.total).fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxY <= 0 ? 100.0 : maxY * 1.26;

    return SizedBox(
      height: _chartHeight,
      child: Padding(
        padding: const EdgeInsets.only(top: _labelHeadroom),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            BarChart(
              duration: Duration.zero,
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false, reservedSize: 0),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: _bottomReserved,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if ((value - index).abs() > 0.001) {
                          return const SizedBox.shrink();
                        }
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              points[index].label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].total,
                          color: AppColors.primary,
                          width: points.length > 8 ? 10 : 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                ],
                barTouchData: BarTouchData(enabled: false),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  0,
                  _horizontalPadding,
                  _bottomReserved,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final point in points)
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final plotHeight = constraints.maxHeight;
                            if (point.total <= 0 || plotHeight <= 0) {
                              return const SizedBox.shrink();
                            }

                            final barTop = plotHeight * (1 - (point.total / chartMax));
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  top: (barTop - 18).clamp(0.0, plotHeight - 14),
                                  left: 0,
                                  right: 0,
                                  child: Text(
                                    _barTopLabel(point.total),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontSize: points.length > 6 ? 8.5 : 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                          height: 1.05,
                                        ),
                                  ),
                                ),
                              ],
                            );
                          },
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

  String _barTopLabel(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}k';
    }
    return formatUsd(value);
  }
}
