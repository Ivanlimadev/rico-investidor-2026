import 'package:flutter/material.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/widgets/transaction_list_tile.dart';

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    this.onViewAll,
    this.onTransactionTap,
  });

  final List<FinanceTransaction> transactions;
  final VoidCallback? onViewAll;
  final ValueChanged<FinanceTransaction>? onTransactionTap;

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Transações recentes', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(onPressed: onViewAll, child: const Text('Ver todas')),
              ],
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhuma transação ainda. Conecte um banco ou adicione manualmente.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              ...recent.map(
                (tx) => FinanceTransactionListTile(
                  transaction: tx,
                  onTap: onTransactionTap == null ? null : () => onTransactionTap!(tx),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
