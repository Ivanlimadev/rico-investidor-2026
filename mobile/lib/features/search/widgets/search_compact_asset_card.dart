import 'package:flutter/material.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/global_markets/widgets/country_hub_mini_asset_card.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

/// Card compacto da aba Buscar — logo, bandeira, ticker e cotação.
class SearchCompactAssetCard extends StatelessWidget {
  const SearchCompactAssetCard({
    super.key,
    required this.asset,
    this.onTap,
    required this.logoSize,
  });

  final AssetItem asset;
  final VoidCallback? onTap;
  final double logoSize;

  static String displaySymbol(String symbol) => CountryHubMiniAssetCard.displaySymbol(symbol);

  static String? formatPrice(AssetItem asset) {
    if (asset.price <= 0) return null;

    return switch (asset.category) {
      MarketCategory.stocks || MarketCategory.reits => _formatUsd(asset.price),
      MarketCategory.cripto => formatCryptoPrice(asset.price),
    };
  }

  static String _formatUsd(double value) {
    if (value >= 1000) return '\$${value.toStringAsFixed(0)}';
    return formatUsd(value);
  }

  @override
  Widget build(BuildContext context) {
    final label = displaySymbol(asset.symbol);
    final priceLabel = formatPrice(asset);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: AssetSearchLeading(asset: asset, logoSize: logoSize),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: searchGridLabelFontSize(logoSize),
                      letterSpacing: 0.1,
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
                        fontWeight: FontWeight.w700,
                        fontSize: searchGridPriceFontSize(logoSize),
                        height: 1.0,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
