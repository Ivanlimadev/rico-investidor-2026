import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';

class BillsCard extends StatelessWidget {
  const BillsCard({
    super.key,
    required this.bills,
    this.onTap,
  });

  final FinanceBills bills;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final items = bills.items.take(4).toList();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Assinaturas', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  if (bills.monthlyTotal > 0)
                    Text(
                      formatUsd(bills.monthlyTotal),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text(
                  'Recorrências aparecem após conectar o banco.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...items.map((bill) {
                  final info = financeCategoryInfo(bill.category);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(info.emoji),
                        const SizedBox(width: 8),
                        Expanded(child: Text(bill.merchantName)),
                        Text('${formatUsd(bill.amount)}/mês'),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
