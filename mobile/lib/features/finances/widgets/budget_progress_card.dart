import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({
    super.key,
    required this.budget,
    this.onTap,
    this.onSetBudget,
  });

  final FinanceBudget budget;
  final VoidCallback? onTap;
  final VoidCallback? onSetBudget;

  @override
  Widget build(BuildContext context) {
    final categories = budget.categories;
    final totalLimit = categories.fold<double>(0, (sum, item) => sum + item.limit);
    final totalSpent = categories.fold<double>(0, (sum, item) => sum + item.spent);
    final hasBudget = totalLimit > 0;
    final progress = hasBudget ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Orçamento', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              if (!hasBudget) ...[
                const Text('Defina um orçamento mensal para acompanhar seus gastos.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onSetBudget ?? onTap,
                  child: const Text('Definir orçamento'),
                ),
              ] else ...[
                Text(
                  'Você usou ${formatUsd(totalSpent)} de ${formatUsd(totalLimit)} este mês',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: totalSpent > totalLimit
                        ? Theme.of(context).colorScheme.error
                        : AppColors.positive,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
