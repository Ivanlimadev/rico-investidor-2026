import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
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
              Text(
                asset.symbol,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
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
              const SizedBox(height: 12),
              Text(
                priceText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    asset.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: changeColor,
                    size: 22,
                  ),
                  Text(
                    '${asset.changePercent.abs().toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(AssetItem asset) {
    if (asset.category == MarketCategory.cripto && asset.symbol == 'BTC') {
      return 'R\$ ${(asset.price / 1000).toStringAsFixed(1)}k';
    }
    if (asset.price >= 1000) {
      return 'R\$ ${asset.price.toStringAsFixed(0)}';
    }
    return 'R\$ ${asset.price.toStringAsFixed(2)}';
  }
}
