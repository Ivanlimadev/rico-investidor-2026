import 'package:flutter/material.dart';
import 'package:rico_investidor/features/finances/data/plaid_link_service.dart';

Future<void> showPlaidSuccessSheet(
  BuildContext context, {
  required PlaidLinkConnectResult result,
}) {
  final exchange = result.exchange;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '${exchange.institutionName} conectado com sucesso!',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${exchange.accountCount} conta(s) encontrada(s)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (result.accountLabels.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...result.accountLabels.map(
                (label) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $label', textAlign: TextAlign.center),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ver minhas contas'),
            ),
          ],
        ),
      );
    },
  );
}
