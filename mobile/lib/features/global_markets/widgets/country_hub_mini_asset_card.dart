import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class CountryHubMiniAssetCard extends StatelessWidget {
  const CountryHubMiniAssetCard({
    super.key,
    required this.asset,
    this.onTap,
    this.logoSize = 28,
    this.binanceStyle = false,
  });

  final AssetItem asset;
  final VoidCallback? onTap;
  final double logoSize;
  final bool binanceStyle;

  static String displaySymbol(String symbol) {
    final dot = symbol.indexOf('.');
    if (dot > 0) return symbol.substring(0, dot);
    return symbol;
  }

  static String formatPrice(AssetItem asset) {
    final isBrazilian = asset.category == MarketCategory.acoesBr ||
        asset.category == MarketCategory.bdr ||
        asset.category == MarketCategory.etf ||
        asset.category == MarketCategory.fiis;

    if (isBrazilian) {
      if (asset.price >= 1000) {
        return 'R\$ ${asset.price.toStringAsFixed(0)}';
      }
      return formatBrl(asset.price);
    }

    final value = asset.price;
    if (value >= 1000) {
      return '\$${value.toStringAsFixed(0)}';
    }
    return formatUsd(value);
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = asset.isPositive ? AppColors.positive : AppColors.negative;
    final label = displaySymbol(asset.symbol);
    final compact = logoSize >= 34 || binanceStyle;
    final changeLabel =
        '${asset.isPositive ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%';

    final Widget changeWidget = binanceStyle
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: changeColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              changeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 9.5,
                height: 1.0,
              ),
            ),
          )
        : Text(
            changeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: changeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 10 : null,
                  height: 1.0,
                ),
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 6 : 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AssetLogo(
                symbol: asset.symbol,
                logoUrl: asset.logoUrl,
                size: logoSize,
                borderRadius: 10,
                style: AssetLogoStyle.vibrant,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          fontSize: compact ? 12 : null,
                          height: 1.0,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPrice(asset),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: binanceStyle ? changeColor : null,
                          fontSize: compact ? 10 : null,
                          height: 1.0,
                        ),
                  ),
                  const SizedBox(height: 3),
                  changeWidget,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
