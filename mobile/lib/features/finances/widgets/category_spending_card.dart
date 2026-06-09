import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';
import 'package:rico_investidor/features/finances/widgets/category_icon.dart';

class CategorySpendingCard extends StatelessWidget {
  const CategorySpendingCard({
    super.key,
    required this.items,
    this.onViewAll,
  });

  final List<CategorySpending> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final maxAmount = items.isEmpty ? 1.0 : items.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Gastos por categoria', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(onPressed: onViewAll, child: const Text('Ver todos')),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'Sem gastos categorizados neste mês.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...items.map((item) {
                final info = financeCategoryInfo(item.category);
                final share = item.amount / maxAmount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      FinanceCategoryIcon(category: item.category),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(info.label)),
                                Text(formatUsd(item.amount)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: share,
                                minHeight: 4,
                                backgroundColor:
                                    Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
