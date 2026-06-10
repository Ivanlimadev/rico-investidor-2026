import 'package:flutter/material.dart';

/// Aviso legal curto — não constitui recomendação de investimento.
class InvestmentDisclaimer extends StatelessWidget {
  const InvestmentDisclaimer({super.key, this.compact = false});

  final bool compact;

  static const text =
      'O Rico Investidor exibe informações de mercado apenas para fins educacionais. '
      'Não recomendamos compra, venda ou manutenção de ativos. '
      'Investimentos envolvem riscos; consulte um profissional antes de decidir.';

  @override
  Widget build(BuildContext context) {
    final style = compact
        ? Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: compact ? 16 : 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
