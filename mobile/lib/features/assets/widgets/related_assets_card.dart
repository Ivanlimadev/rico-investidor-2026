import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/assets/data/related_assets_api_client.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/assets/models/related_assets.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class RelatedAssetsCard extends StatelessWidget {
  const RelatedAssetsCard({
    super.key,
    required this.ticker,
    required this.market,
    this.sector,
    this.industry,
    this.title = 'Ativos relacionados',
    this.limit = 6,
  });

  final String ticker;
  final String market;
  final String? sector;
  final String? industry;
  final String title;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RelatedAssetsResponseDto>(
      future: relatedAssetsApiClient.listRelated(
        ticker,
        market: market,
        sector: sector,
        industry: industry,
        limit: limit,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RelatedShell(
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
          return const SizedBox.shrink();
        }

        final response = snapshot.data!;

        return _RelatedShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.hub_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (response.groupLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              response.groupLabel,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.12,
                ),
                itemCount: response.items.length,
                itemBuilder: (context, index) {
                  final item = response.items[index];
                  return _RelatedMiniTile(
                    item: item,
                    onTap: () => _openRelated(context, item),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRelated(BuildContext context, RelatedAssetItemDto item) {
    openTickerDetail(
      context,
      ticker: item.symbol,
      category: item.marketCategory,
      exchangeMic: item.exchangeMic,
    );
  }
}

class _RelatedShell extends StatelessWidget {
  const _RelatedShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: child,
      ),
    );
  }
}

class _RelatedMiniTile extends StatelessWidget {
  const _RelatedMiniTile({required this.item, required this.onTap});

  final RelatedAssetItemDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = item.changePercent >= 0;
    final changeColor = positive ? AppColors.positive : AppColors.negative;
    final priceText = item.marketCategory == MarketCategory.cripto
        ? formatCryptoPrice(item.price, currency: 'USD')
        : (item.marketCategory == MarketCategory.stocks || item.marketCategory == MarketCategory.reits)
            ? formatUsd(item.price)
            : formatBrl(item.price);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.45)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 4, color: AppColors.primary)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AssetLogo(
                        symbol: item.symbol,
                        logoUrl: item.logoUrl,
                        size: kAssetLogoSizeCompact,
                        borderRadius: kAssetLogoBorderRadius,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.symbol,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.reason,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        priceText,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${positive ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(color: changeColor, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
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
