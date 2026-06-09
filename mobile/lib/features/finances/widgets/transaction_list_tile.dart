import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';
import 'package:rico_investidor/features/finances/widgets/category_icon.dart';

class FinanceTransactionListTile extends StatelessWidget {
  const FinanceTransactionListTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final FinanceTransaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = transaction.merchantName ?? transaction.name;
    final info = financeCategoryInfo(transaction.category);
    final amountColor = transaction.isIncome ? AppColors.positive : Theme.of(context).colorScheme.error;
    final amountPrefix = transaction.isIncome ? '+' : '';
    final dateLabel =
        '${transaction.date.day.toString().padLeft(2, '0')}/${transaction.date.month.toString().padLeft(2, '0')}';

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: FinanceCategoryIcon(category: transaction.category),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$dateLabel · ${info.label}${transaction.isPending ? ' · pendente' : ''}'),
      trailing: Text(
        '$amountPrefix${formatUsd(transaction.amount.abs())}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
