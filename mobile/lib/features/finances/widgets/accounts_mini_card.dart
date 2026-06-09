import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';

class AccountsMiniCard extends StatelessWidget {
  const AccountsMiniCard({
    super.key,
    required this.accounts,
    this.onAddAccount,
    this.onViewAll,
  });

  final List<PlaidAccount> accounts;
  final VoidCallback? onAddAccount;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Contas bancárias', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (onViewAll != null && accounts.isNotEmpty)
                  TextButton(onPressed: onViewAll, child: const Text('Ver todas')),
              ],
            ),
            const SizedBox(height: 10),
            if (accounts.isEmpty)
              OutlinedButton.icon(
                onPressed: onAddAccount,
                icon: const Icon(Icons.add),
                label: const Text('Conectar banco'),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [
                  ...accounts.take(3).map(
                    (account) => _AccountTile(account: account),
                  ),
                  _AddAccountTile(onTap: onAddAccount),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final PlaidAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.institutionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '•••• ${account.mask}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            formatUsd(account.currentBalance),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AddAccountTile extends StatelessWidget {
  const _AddAccountTile({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}
