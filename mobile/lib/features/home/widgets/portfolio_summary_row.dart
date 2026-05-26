import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/models/portfolio_summary.dart';

class PortfolioSummaryRow extends StatelessWidget {
  const PortfolioSummaryRow({
    super.key,
    required this.summary,
    required this.onPortfolioTap,
    required this.onDividendsTap,
  });

  final PortfolioSummary summary;
  final VoidCallback onPortfolioTap;
  final VoidCallback onDividendsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SummaryCard(
                onTap: onPortfolioTap,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Saldo da carteira',
                amount: formatBrl(summary.totalBalance),
                changeLabel: '${summary.isPortfolioUp ? '+' : ''}'
                    '${summary.portfolioChangePercent.toStringAsFixed(2)}% '
                    'no mês',
                isPositive: summary.isPortfolioUp,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                onTap: onDividendsTap,
                icon: Icons.payments_outlined,
                label: 'Dividendos no mês',
                amount: formatBrl(summary.monthlyDividends),
                changeLabel: '${summary.isDividendsUp ? '+' : ''}'
                    '${summary.dividendsVsLastMonthPercent.toStringAsFixed(1)}% '
                    'vs mês anterior',
                isPositive: summary.isDividendsUp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.amount,
    required this.changeLabel,
    required this.isPositive,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final String amount;
  final String changeLabel;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final changeColor = isPositive ? AppColors.positive : AppColors.negative;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                amount,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: changeColor,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      changeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
