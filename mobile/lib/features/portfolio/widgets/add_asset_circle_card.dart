import 'package:flutter/material.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/search/widgets/search_compact_asset_card.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Mini card circular — exclusivo da seção Adicionar ativo (favoritos, recentes, principais).
class AddAssetCircleAssetCard extends StatelessWidget {
  const AddAssetCircleAssetCard({
    super.key,
    required this.asset,
    required this.logoSize,
    this.onTap,
  });

  final AssetItem asset;
  final double logoSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = SearchCompactAssetCard.displaySymbol(asset.symbol);
    final priceLabel = SearchCompactAssetCard.formatPrice(asset);
    final flagSize = (logoSize * 0.28).clamp(11.0, 16.0);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
              SizedBox(
                width: logoSize + flagSize * 0.35,
                height: logoSize + flagSize * 0.35,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: AssetLogo(
                          symbol: asset.symbol,
                          logoUrl: asset.logoUrl,
                          size: logoSize,
                          borderRadius: logoSize / 2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: AssetCountryFlag(asset: asset, size: flagSize),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: searchGridLabelFontSize(logoSize),
                      height: 1.05,
                    ),
              ),
              if (priceLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: searchGridPriceFontSize(logoSize),
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                ),
              ],
            ],
          ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}
