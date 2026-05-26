import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';

class FinancesTabScreen extends StatelessWidget {
  const FinancesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const monthlyBudget = 4500.0;
    const spent = 2870.40;
    const remaining = monthlyBudget - spent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, kBottomNavContentPadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.savings,
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Orçamento do mês', style: Theme.of(context).textTheme.labelLarge),
                        Text(
                          formatBrl(remaining),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.positive,
                              ),
                        ),
                        Text(
                          'restante de ${formatBrl(monthlyBudget)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: const Text('Demo'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Organize seu dinheiro', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          const _FinanceFeatureCard(
            icon: Icons.receipt_long_outlined,
            title: 'Gastos e receitas',
            subtitle: 'Registre entradas, saídas e categorize cada movimento.',
          ),
          const SizedBox(height: 12),
          const _FinanceFeatureCard(
            icon: Icons.savings_outlined,
            title: 'Metas de economia',
            subtitle: 'Defina objetivos e acompanhe quanto falta para alcançar.',
          ),
          const SizedBox(height: 12),
          const _FinanceFeatureCard(
            icon: Icons.account_balance_outlined,
            title: 'Contas e cartões',
            subtitle: 'Centralize saldos bancários e faturas em um só lugar.',
          ),
          const SizedBox(height: 12),
          const _FinanceFeatureCard(
            icon: Icons.pie_chart_outline,
            title: 'Relatórios',
            subtitle: 'Veja para onde vai seu dinheiro mês a mês.',
          ),
          const SizedBox(height: 16),
          Text(
            'Finanças pessoais completas chegam em breve. Os valores acima são apenas demonstração.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FinanceFeatureCard extends StatelessWidget {
  const _FinanceFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
                      ),
                      Chip(
                        label: const Text('Em breve'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
