import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/core/widgets/quote_sparkline.dart';
import 'package:rico_investidor/core/utils/percent_format.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class FeaturedAssetCard extends StatelessWidget {
  const FeaturedAssetCard({super.key, required this.asset, this.onTap});

  final AssetItem asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final changeColor = asset.isPositive ? AppColors.positive : AppColors.negative;
    final priceText = _formatPrice(asset);
    final hasDy = asset.dividendYield12m != null;
    final hasPvp = asset.priceToBook != null;

    return SizedBox(
      width: 168,
      height: 184,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AssetLogo(
                  symbol: asset.symbol,
                  logoUrl: asset.logoUrl,
                  size: kAssetLogoSizeCard,
                  borderRadius: kAssetLogoBorderRadius,
                  style: AssetLogoStyle.vibrant,
                ),
                const SizedBox(height: 10),
                Text(
                  asset.symbol,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                if (asset.sparkline.length >= 2) ...[
                  const SizedBox(height: 8),
                  QuoteSparkline(
                    values: asset.sparkline,
                    positive: asset.isPositive,
                    width: double.infinity,
                    height: 36,
                  ),
                ],
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        priceText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                    ),
                    if (asset.category == MarketCategory.stocks ||
                        asset.category == MarketCategory.reits)
                      QuoteChangeBadge(
                        changePercent: asset.changePercent,
                        positive: asset.isPositive,
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            asset.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            color: changeColor,
                            size: 22,
                          ),
                          Text(
                            '${asset.changePercent.abs().toStringAsFixed(2)}%',
                            style: TextStyle(color: changeColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
                if (hasDy || hasPvp) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (hasDy)
                        Text(
                          'DY ${formatPct(asset.dividendYield12m!)}',
                          style: const TextStyle(
                            color: AppColors.positive,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      if (hasDy && hasPvp) const SizedBox(width: 8),
                      if (hasPvp)
                        Flexible(
                          child: Text(
                            'P/VP ${asset.priceToBook!.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.2),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(AssetItem asset) {
    if (asset.category == MarketCategory.stocks || asset.category == MarketCategory.reits) {
      if (asset.price >= 1000) {
        return '\$${asset.price.toStringAsFixed(0)}';
      }
      return '\$${asset.price.toStringAsFixed(2)}';
    }
    if (asset.category == MarketCategory.cripto && asset.symbol == 'BTC') {
      return 'R\$ ${(asset.price / 1000).toStringAsFixed(1)}k';
    }
    if (asset.price >= 1000) {
      return 'R\$ ${asset.price.toStringAsFixed(0)}';
    }
    return 'R\$ ${asset.price.toStringAsFixed(2)}';
  }
}
