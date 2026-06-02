import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiDistributionsChart extends StatefulWidget {
  const FiiDistributionsChart({
    super.key,
    required this.annualSummary,
    this.title = 'Proventos por cota (anual)',
    this.valueFormatter = formatBrl,
    this.maxYears = 10,
  });

  final List<FiiDistributionYear> annualSummary;
  final String title;
  final String Function(double value) valueFormatter;
  final int maxYears;

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

    final maxYears = widget.maxYears.clamp(4, 20);
    final truncated = sorted.length > maxYears;
    final visible = truncated ? sorted.sublist(sorted.length - maxYears) : sorted;

    final maxValue = visible
        .map((row) => row.totalPerShare ?? 0)
        .fold(0.0, (current, value) => value > current ? value : current);
    final chartMax = maxValue <= 0 ? 1.0 : maxValue * 1.18;
    final barWidth = visible.length > 10 ? 10.0 : visible.length > 7 ? 14.0 : 18.0;
    final groupsSpace = visible.length > 8 ? 8.0 : 14.0;

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < visible.length; i++) {
      final isSelected = _selectedIndex == i;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: visible[i].totalPerShare ?? 0,
              color: isSelected ? AppColors.positive : AppColors.positive.withValues(alpha: 0.78),
              width: isSelected ? barWidth + 2 : barWidth,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final selected = _selectedIndex != null && _selectedIndex! < visible.length
        ? visible[_selectedIndex!]
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
                ),
                if (truncated)
                  Text(
                    'Últimos $maxYears anos',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                  ),
              ],
            ),
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
                          ? widget.valueFormatter(selected.totalPerShare!)
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
              height: 176,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMax,
                  groupsSpace: groupsSpace,
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
                        final value = visible[groupIndex].totalPerShare;
                        return BarTooltipItem(
                          '${visible[groupIndex].year}\n${value != null ? widget.valueFormatter(value) : '—'}',
                          TextStyle(
                            color: Theme.of(context).colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if ((value - index).abs() > 0.001) {
                            return const SizedBox.shrink();
                          }
                          if (index < 0 || index >= visible.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${visible[index].year}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: visible.length > 8 ? 9 : 11,
                                    ),
                              ),
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
