import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/utils/portfolio_balance.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

enum PortfolioBalanceHeroLayout { compact, expanded }

/// Saldo da carteira com moeda conforme preferência e bloco de dolarização (sem BDRs).
class PortfolioBalanceHero extends StatelessWidget {
  const PortfolioBalanceHero({
    super.key,
    required this.portfolio,
    required this.preferredMarket,
    this.layout = PortfolioBalanceHeroLayout.expanded,
    this.onTap,
  });

  final PortfolioState portfolio;
  final MarketPreference preferredMarket;
  final PortfolioBalanceHeroLayout layout;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final breakdown = portfolio.computeBalanceBreakdown();
    final isBrazil = preferredMarket.isBrazil;
    final primaryCurrency = isBrazil ? HoldingCurrency.brl : HoldingCurrency.usd;
    final primaryTotal = breakdown.primaryTotal(preferredMarket);
    final profitPct = breakdown.primaryProfitPercent(preferredMarket);
    final profitUp = profitPct >= 0;
    final profitColor = profitUp ? AppColors.positive : AppColors.negative;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _MarketBadge(isBrazil: isBrazil),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBrazil ? 'Patrimônio total' : 'Portfolio total',
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
            primaryCurrency.format(primaryTotal),
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
              '${profitUp ? '+' : ''}${profitPct.toStringAsFixed(2)}% lucro total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: profitColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        if (layout == PortfolioBalanceHeroLayout.expanded && breakdown.isMixed) ...[
          const SizedBox(height: 16),
          _SplitBuckets(breakdown: breakdown, preferredMarket: preferredMarket),
        ] else if (layout == PortfolioBalanceHeroLayout.expanded &&
            breakdown.hasInternational &&
            isBrazil) ...[
          const SizedBox(height: 16),
          _InternationalExposureCard(
            amountUsd: breakdown.internationalMarketValueUsd,
            sharePercent: breakdown.internationalSharePercent(preferredMarket),
            profitPercent: breakdown.internationalProfitPercent,
          ),
        ] else if (layout == PortfolioBalanceHeroLayout.expanded &&
            breakdown.hasDomestic &&
            !isBrazil) ...[
          const SizedBox(height: 16),
          _DomesticBrazilCard(
            amountBrl: breakdown.domesticMarketValueBrl,
            sharePercent: breakdown.domesticSharePercent(preferredMarket),
            profitPercent: breakdown.domesticProfitPercent,
            usdBrlRate: breakdown.usdBrlRate,
          ),
        ],
        if (breakdown.usdBrlRate != null &&
            (breakdown.isMixed || breakdown.hasInternational) &&
            layout == PortfolioBalanceHeroLayout.expanded) ...[
          const SizedBox(height: 12),
          Text(
            'Câmbio USD/BRL ${breakdown.usdBrlRate!.toStringAsFixed(2)} · BDRs contam em reais',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
          ),
        ],
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
  const _MarketBadge({required this.isBrazil});

  final bool isBrazil;

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
        countryCode: isBrazil ? 'BR' : 'US',
        size: 22,
        borderRadius: 6,
      ),
    );
  }
}

class _SplitBuckets extends StatelessWidget {
  const _SplitBuckets({
    required this.breakdown,
    required this.preferredMarket,
  });

  final PortfolioBalanceBreakdown breakdown;
  final MarketPreference preferredMarket;

  @override
  Widget build(BuildContext context) {
    final isBrazil = preferredMarket.isBrazil;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _BucketTile(
              flag: '🇧🇷',
              title: 'Brasil',
              subtitle: 'Ações, FIIs, BDRs, ETFs B3',
              amount: formatBrl(breakdown.domesticMarketValueBrl),
              share: breakdown.domesticSharePercent(preferredMarket),
              accent: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BucketTile(
              flag: '🇺🇸',
              title: isBrazil ? 'Internacional' : 'EUA direto',
              subtitle: isBrazil ? 'Dolarização · sem BDRs' : 'Corretoras americanas',
              amount: formatUsd(breakdown.internationalMarketValueUsd),
              share: breakdown.internationalSharePercent(preferredMarket),
              accent: const Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketTile extends StatelessWidget {
  const _BucketTile({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.share,
    required this.accent,
  });

  final String flag;
  final String title;
  final String subtitle;
  final String amount;
  final double share;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${share.toStringAsFixed(1)}% da carteira',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _InternationalExposureCard extends StatelessWidget {
  const _InternationalExposureCard({
    required this.amountUsd,
    required this.sharePercent,
    required this.profitPercent,
  });

  final double amountUsd;
  final double sharePercent;
  final double profitPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Text('🇺🇸', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exposição internacional',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1565C0),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ativos em dólar (EUA) · BDRs não entram aqui',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatUsd(amountUsd),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${sharePercent.toStringAsFixed(1)}% · ${profitPercent >= 0 ? '+' : ''}${profitPercent.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DomesticBrazilCard extends StatelessWidget {
  const _DomesticBrazilCard({
    required this.amountBrl,
    required this.sharePercent,
    required this.profitPercent,
    this.usdBrlRate,
  });

  final double amountBrl;
  final double sharePercent;
  final double profitPercent;
  final double? usdBrlRate;

  @override
  Widget build(BuildContext context) {
    final converted = usdBrlRate != null && usdBrlRate! > 0
        ? '≈ ${formatUsd(amountBrl / usdBrlRate!)}'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Text('🇧🇷', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ativos no Brasil',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatBrl(amountBrl),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${sharePercent.toStringAsFixed(1)}% · ${profitPercent >= 0 ? '+' : ''}${profitPercent.toStringAsFixed(1)}%'
                  '${converted != null ? ' · $converted' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
