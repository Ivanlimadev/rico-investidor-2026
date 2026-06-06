import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/asset_magic_number.dart';
import 'package:rico_investidor/models/holding_currency.dart';

class AssetMagicNumberCard extends StatelessWidget {
  const AssetMagicNumberCard({
    super.key,
    required this.result,
    required this.unitLabel,
    required this.unitPlural,
    required this.currency,
    this.priceLabel = 'Preço atual',
    this.dividendLabel = 'Provento médio/mês',
  });

  final AssetMagicNumberResult result;
  final String unitLabel;
  final String unitPlural;
  final HoldingCurrency currency;
  final String priceLabel;
  final String dividendLabel;

  @override
  Widget build(BuildContext context) {
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
              'Quantas $unitPlural você precisa ter para que os proventos de 1 mês '
              'comprem mais 1 $unitLabel ao preço atual.',
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
                  child: Text(unitPlural, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: dividendLabel, value: currency.format(result.monthlyDividendPerShare)),
            _InfoRow(label: priceLabel, value: currency.format(result.price)),
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

class AssetMagicNumberCompact extends StatelessWidget {
  const AssetMagicNumberCompact({
    super.key,
    required this.result,
    required this.unitPlural,
    required this.currency,
  });

  final AssetMagicNumberResult result;
  final String unitPlural;
  final HoldingCurrency currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.auto_graph, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Magic Number', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${result.magicNumber} $unitPlural · ${currency.format(result.monthlyDividendPerShare)}/mês',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
            Text(
              '${result.magicNumber}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.positive,
                  ),
            ),
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
