import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_magic_number.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiMagicNumberCard extends StatelessWidget {
  const FiiMagicNumberCard({
    super.key,
    required this.detail,
    this.distributions,
    this.history = const [],
  });

  final FiiDetail detail;
  final FiiDistributions? distributions;
  final List<FiiHistoryPoint> history;

  @override
  Widget build(BuildContext context) {
    final result = computeMagicNumber(
      detail: detail,
      distributions: distributions,
      history: history,
    );

    if (result == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Magic Number', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quantas cotas você precisa ter para que os proventos de 1 mês '
              'comprem mais 1 cota ao preço atual.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${result.magicNumber}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.positive,
                        height: 1,
                      ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('cotas', style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Provento médio/mês',
              value: formatBrl(result.monthlyDividendPerShare),
            ),
            _InfoRow(label: 'Cotação atual', value: formatBrl(result.price)),
            if (result.source != null) ...[
              const SizedBox(height: 8),
              Text(
                'Base: ${result.source}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
