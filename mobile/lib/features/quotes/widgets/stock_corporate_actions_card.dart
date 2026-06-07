import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/dividend_payment_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class StockCorporateActionsCard extends StatelessWidget {
  const StockCorporateActionsCard({super.key, required this.actions});

  final List<StockCorporateActionDto> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Eventos corporativos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (var i = 0; i < actions.length; i++) ...[
              _ActionRow(action: actions[i]),
              if (i < actions.length - 1) const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final StockCorporateActionDto action;

  @override
  Widget build(BuildContext context) {
    final label = action.label ?? 'Evento';
    final factor = action.completeFactor ?? (action.factor != null ? '${action.factor}x' : null);
    final date = formatPaymentDate(action.exDate);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (factor != null)
                Text(
                  factor,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
            ],
          ),
        ),
        Text(date, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
