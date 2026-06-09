import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/markets/supported_market_countries.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/portfolio_allocation_slice.dart';
import 'package:rico_investidor/l10n/app_strings.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioAllocationCard extends StatelessWidget {
  const PortfolioAllocationCard({
    super.key,
    required this.portfolio,
    required this.preferredMarket,
    this.onTap,
  });

  final PortfolioState portfolio;
  final MarketPreference preferredMarket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final slices = portfolio.computeAllocation(defaultMarketPreference);
    final total = portfolio.patrimonioTotalUsd;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.portfolioAllocation,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slices.isEmpty
                      ? AppStrings.addAssetsToSeeChart
                      : '${AppStrings.portfolioTotalLabel}: ${HoldingCurrency.usd.format(total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                if (slices.isEmpty)
                  _EmptyAllocation(onTap: onTap)
                else
                  RepaintBoundary(
                    child: SizedBox(
                      height: 168,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 11,
                            child: _AllocationPieChart(slices: slices),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 12,
                            child: _AllocationLegend(slices: slices),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAllocation extends StatelessWidget {
  const _EmptyAllocation({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 36,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.emptyPortfolio,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onTap != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onTap,
                child: const Text(AppStrings.addAsset),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllocationPieChart extends StatelessWidget {
  const _AllocationPieChart({required this.slices});

  final List<PortfolioAllocationSlice> slices;

  @override
  Widget build(BuildContext context) {
    return PieChart(
      duration: Duration.zero,
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: [
          for (final slice in slices)
            PieChartSectionData(
              value: slice.value,
              color: slice.color,
              radius: 52,
              showTitle: false,
            ),
        ],
      ),
    );
  }
}

class _AllocationLegend extends StatelessWidget {
  const _AllocationLegend({required this.slices});

  final List<PortfolioAllocationSlice> slices;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < slices.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: slices[index].color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: slices[index].color.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slices[index].label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${slices[index].percent.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
