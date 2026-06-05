import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/async_section_placeholder.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_macro.dart';

class StockMacroCard extends StatelessWidget {
  const StockMacroCard({super.key, required this.repository});

  final QuoteRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BrazilMacroDto>(
      future: repository.getBrazilMacro(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return const AsyncSectionPlaceholder(
            title: 'Contexto macro',
            message: 'Não foi possível carregar Selic, IPCA e CDI. Puxe para atualizar.',
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const AsyncSectionPlaceholder(
            title: 'Contexto macro',
            message: 'Indicadores macro indisponíveis no momento.',
          );
        }

        final macro = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Contexto macro', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (macro.selic != null)
                      _MacroTile(
                        label: 'Selic',
                        value: '${macro.selic!.toStringAsFixed(2)}% a.a.',
                        subtitle: macro.selicAsOf,
                      ),
                    if (macro.ipca12m != null)
                      _MacroTile(
                        label: 'IPCA 12m',
                        value: '${macro.ipca12m!.toStringAsFixed(2)}%',
                        subtitle: macro.ipcaAsOf,
                      ),
                    if (macro.cdi != null)
                      _MacroTile(
                        label: 'CDI',
                        value: '${macro.cdi!.toStringAsFixed(2)}% a.a.',
                        subtitle: macro.cdiAsOf,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}
