import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_property_state.dart';
import 'package:rico_investidor/models/fii_models.dart';

const _pieColors = [
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF009688),
  Color(0xFFE91E63),
  Color(0xFF795548),
  Color(0xFF607D8B),
  Color(0xFF3F51B5),
  Color(0xFFCDDC39),
];

class FiiPropertiesStatePieCard extends StatelessWidget {
  const FiiPropertiesStatePieCard({
    super.key,
    required this.properties,
    this.totalPropertyCount,
  });

  final List<FiiProperty> properties;
  final int? totalPropertyCount;

  @override
  Widget build(BuildContext context) {
    final slices = computePropertyStateSlices(properties);
    if (slices.isEmpty) return const SizedBox.shrink();

    final usesRevenue = properties.any((p) => (p.revenuePct ?? 0) > 0);
    final listedCount = properties.length;
    final totalCount = totalPropertyCount ?? listedCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Imóveis por estado',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              usesRevenue
                  ? 'Participação na receita dos imóveis listados, por UF.'
                  : 'Quantidade de imóveis listados, por UF.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (totalCount > listedCount) ...[
              const SizedBox(height: 4),
              Text(
                'Exibindo $listedCount de $totalCount imóveis do fundo.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 168,
              child: Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          for (var i = 0; i < slices.length; i++)
                            PieChartSectionData(
                              value: slices[i].percent,
                              color: _pieColors[i % _pieColors.length],
                              radius: 52,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 12,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: slices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final slice = slices[index];
                        final color = _pieColors[index % _pieColors.length];
                        return Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                slice.state,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                            Text(
                              '${slice.count} ${slice.count == 1 ? 'imóvel' : 'imóveis'}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatPct(slice.percent),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
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
          ],
        ),
      ),
    );
  }
}
