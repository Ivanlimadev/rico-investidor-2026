import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';

const kAssetLogoSizeList = 40.0;
const kAssetLogoSizeCard = 38.0;
const kAssetLogoSizeCompact = 36.0;
const kAssetLogoBorderRadius = 10.0;

/// Cabeçalho padrão de cards/listas com logo + ticker + nome.
class AssetCardHeader extends StatelessWidget {
  const AssetCardHeader({
    super.key,
    required this.symbol,
    required this.name,
    this.logoUrl,
    this.logoSize = kAssetLogoSizeList,
    this.nameMaxLines = 2,
    this.trailing,
  });

  final String symbol;
  final String name;
  final String? logoUrl;
  final double logoSize;
  final int nameMaxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssetLogo(
          symbol: symbol,
          logoUrl: logoUrl,
          size: logoSize,
          borderRadius: kAssetLogoBorderRadius,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: nameMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// Leading padrão para ListTile de ativos.
class AssetListLeading extends StatelessWidget {
  const AssetListLeading({
    super.key,
    required this.symbol,
    this.logoUrl,
    this.size = kAssetLogoSizeList,
  });

  final String symbol;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AssetLogo(
      symbol: symbol,
      logoUrl: logoUrl,
      size: size,
      borderRadius: kAssetLogoBorderRadius,
    );
  }
}
