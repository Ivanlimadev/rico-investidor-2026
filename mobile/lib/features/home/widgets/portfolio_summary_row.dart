import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/portfolio/widgets/portfolio_balance_hero.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioSummaryRow extends StatelessWidget {
  const PortfolioSummaryRow({
    super.key,
    required this.portfolio,
    required this.preferredMarket,
    required this.onPortfolioTap,
    this.onDividendsTap,
    this.countryCode,
    this.showDividendsCard = true,
  });

  final PortfolioState portfolio;
  final MarketPreference preferredMarket;
  final VoidCallback onPortfolioTap;
  final VoidCallback? onDividendsTap;
  final String? countryCode;
  final bool showDividendsCard;

  @override
  Widget build(BuildContext context) {
    final summary = portfolio.buildSummary(preferredMarket);

    if (!showDividendsCard) {
      return PortfolioBalanceHero(
        portfolio: portfolio,
        preferredMarket: preferredMarket,
        countryCode: countryCode,
        layout: PortfolioBalanceHeroLayout.expanded,
        onTap: onPortfolioTap,
      );
    }

    final dividendsCard = _SummaryCard(
      onTap: onDividendsTap,
      icon: Icons.payments_outlined,
      label: preferredMarket.isBrazil
          ? 'Dividendos no mês (R\$)'
          : 'Dividends this month (US\$)',
      amount: summary.displayCurrency.format(summary.monthlyDividends),
      changeLabel: '${summary.isDividendsUp ? '+' : ''}'
          '${summary.dividendsVsLastMonthPercent.toStringAsFixed(1)}% '
          'vs mês anterior',
      isPositive: summary.isDividendsUp,
    );

    return Column(
      children: [
        PortfolioBalanceHero(
          portfolio: portfolio,
          preferredMarket: preferredMarket,
          countryCode: countryCode,
          layout: PortfolioBalanceHeroLayout.compact,
          onTap: onPortfolioTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: dividendsCard,
        ),
      ],
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

  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final String amount;
  final String changeLabel;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final changeColor = isPositive ? AppColors.positive : AppColors.negative;

    final content = Padding(
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
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}
