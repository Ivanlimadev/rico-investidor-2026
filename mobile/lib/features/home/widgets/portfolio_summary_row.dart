import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
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
    this.syncMessage,
    this.syncing = false,
  });

  final PortfolioState portfolio;
  final MarketPreference preferredMarket;
  final VoidCallback onPortfolioTap;
  final VoidCallback? onDividendsTap;
  final String? countryCode;
  final bool showDividendsCard;
  final String? syncMessage;
  final bool syncing;

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
      label: 'Dividendos no mês',
      amount: formatUsd(summary.monthlyDividends),
      subtitle: 'Toque para ver ativos, datas e valores estimados',
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
        if (syncing || syncMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                if (syncing) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sincronizando carteira…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      syncMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: syncMessage!.contains('Sem conexão')
                                ? Theme.of(context).colorScheme.error
                                : AppColors.positive,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
              ],
            ),
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
    required this.label,
    required this.amount,
    required this.subtitle,
    required this.changeLabel,
    required this.isPositive,
  });

  final VoidCallback? onTap;
  final String label;
  final String amount;
  final String subtitle;
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'DY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.positive,
                      ),
                ),
              ),
              const SizedBox(width: 8),
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
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
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
