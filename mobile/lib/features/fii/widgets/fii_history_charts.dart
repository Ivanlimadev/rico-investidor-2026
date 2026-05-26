import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiDistributionsChart extends StatefulWidget {
  const FiiDistributionsChart({super.key, required this.annualSummary});

  final List<FiiDistributionYear> annualSummary;

  @override
  State<FiiDistributionsChart> createState() => _FiiDistributionsChartState();
}

class _FiiDistributionsChartState extends State<FiiDistributionsChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.annualSummary.isEmpty) return const SizedBox.shrink();

    final sorted = List<FiiDistributionYear>.from(widget.annualSummary)
      ..sort((a, b) => a.year.compareTo(b.year));

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < sorted.length; i++) {
      final isSelected = _selectedIndex == i;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: sorted[i].totalPerShare ?? 0,
              color: isSelected ? AppColors.positive : AppColors.positive.withValues(alpha: 0.75),
              width: isSelected ? 20 : 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final selected = _selectedIndex != null && _selectedIndex! < sorted.length
        ? sorted[_selectedIndex!]
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Proventos por cota (anual)', style: Theme.of(context).textTheme.titleSmall),
            if (selected != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('${selected.year}', style: Theme.of(context).textTheme.labelLarge),
                    const Spacer(),
                    Text(
                      selected.totalPerShare != null
                          ? formatBrl(selected.totalPerShare!)
                          : '—',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.positive,
                          ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Toque na barra para ver o valor',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      final index = response?.spot?.touchedBarGroupIndex;
                      if (index == null) return;
                      setState(() => _selectedIndex = index);
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final value = sorted[groupIndex].totalPerShare;
                        return BarTooltipItem(
                          value != null ? formatBrl(value) : '—',
                          TextStyle(
                            color: Theme.of(context).colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${sorted[i].year}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: bars,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
