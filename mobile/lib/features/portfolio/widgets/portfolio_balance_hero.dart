import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/l10n/app_strings.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

enum PortfolioBalanceHeroLayout { compact, expanded }

/// Saldo da carteira com moeda conforme preferência e bloco de dolarização (sem BDRs).
class PortfolioBalanceHero extends StatelessWidget {
  const PortfolioBalanceHero({
    super.key,
    required this.portfolio,
    required this.preferredMarket,
    this.countryCode,
    this.layout = PortfolioBalanceHeroLayout.expanded,
    this.onTap,
  });

  final PortfolioState portfolio;
  final MarketPreference preferredMarket;
  final String? countryCode;
  final PortfolioBalanceHeroLayout layout;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final breakdown = portfolio.computeBalanceBreakdown();
    final isBrazil = preferredMarket.isBrazil;
    final effectiveCountryCode = countryCode?.trim().toUpperCase();
    final badgeCountryCode = effectiveCountryCode != null && effectiveCountryCode.isNotEmpty
      ? effectiveCountryCode
      : (isBrazil ? 'BR' : 'US');
    final totalUsd = breakdown.internationalMarketValueUsd;
    final investedUsd = breakdown.internationalInvestedUsd;
    final profitPct =
        investedUsd <= 0 ? 0.0 : ((totalUsd - investedUsd) / investedUsd) * 100;
    final profitUp = profitPct >= 0;
    final profitColor = profitUp ? AppColors.positive : AppColors.negative;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _MarketBadge(countryCode: badgeCountryCode),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.portfolioTotal,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    preferredMarket.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
            if (layout == PortfolioBalanceHeroLayout.compact)
              Icon(
                profitUp ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: profitColor,
              ),
          ],
        ),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            HoldingCurrency.usd.format(totalUsd),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              profitUp ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: profitColor,
            ),
            const SizedBox(width: 4),
            Text(
              '${profitUp ? '+' : ''}${profitPct.toStringAsFixed(2)}% ${AppStrings.totalProfit}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: profitColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );

    final padding = layout == PortfolioBalanceHeroLayout.compact
        ? const EdgeInsets.all(14)
        : const EdgeInsets.all(18);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, layout == PortfolioBalanceHeroLayout.compact ? 12 : 8, 20, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: layout == PortfolioBalanceHeroLayout.expanded ? 0 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: layout == PortfolioBalanceHeroLayout.expanded
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: layout == PortfolioBalanceHeroLayout.expanded
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  )
                : null,
            padding: padding,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _MarketBadge extends StatelessWidget {
  const _MarketBadge({required this.countryCode});

  final String countryCode;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: CountryFlagImage(
        countryCode: countryCode,
        size: 22,
        borderRadius: 6,
      ),
    );
  }
}
