import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/utils/fii_fund_costs.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiFundCostsCard extends StatelessWidget {
  const FiiFundCostsCard({super.key, required this.detail});

  final FiiDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = buildFiiFundCostsSummary(detail);
    if (summary == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final canShowPerShare =
        detail.sharesOutstanding != null && detail.sharesOutstanding! > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Quanto o fundo pagou ao administrador', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              canShowPerShare
                  ? 'Valores do último mês registrado. Abaixo você vê o impacto '
                      'por cota — o que importa para quem investe.'
                  : 'Valores totais pagos pelo fundo no último mês registrado.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < summary.lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _CostBlock(line: summary.lines[i], showPerShare: canShowPerShare),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Text(
                'Entenda esses números',
                style: theme.textTheme.labelLarge,
              ),
              children: [
                Text(
                  '• Isso não é a taxa % do regulamento (ex.: 0,85% ao ano).\n'
                  '• É o dinheiro que o fundo já pagou ao administrador no período.\n'
                  '• Os dados vêm do informe da CVM e podem ter alguns meses de atraso.\n'
                  '• A cotação mostrada no topo é outra informação (preço de mercado).',
                  style: theme.textTheme.bodySmall,
                ),
                if (detail.referenceDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Referência do fundo: ${detail.referenceDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CostBlock extends StatelessWidget {
  const _CostBlock({required this.line, required this.showPerShare});

  final FiiFundCostLine line;
  final bool showPerShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          if (showPerShare) ...[
            Text('Por cota no mês', style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              line.perShareLabel,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Exemplo: com 100 cotas → ${line.example100Label} no mês',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Total pago pelo fundo: ${line.totalFundLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ] else ...[
            Text('Total pago pelo fundo', style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              line.totalFundLabel,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}
