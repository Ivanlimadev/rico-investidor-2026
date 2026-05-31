import 'package:flutter/material.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/features/search/widgets/search_compact_asset_card.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Grid 3 colunas compartilhado — favoritos e resultados da busca.
class SearchAssetGrid extends StatelessWidget {
  const SearchAssetGrid({
    super.key,
    required this.assets,
    required this.onAssetTap,
  });

  final List<AssetItem> assets;
  final ValueChanged<AssetItem> onAssetTap;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = searchGridCellWidth(
          gridWidth: constraints.maxWidth,
          columns: kSearchFavoritesGridColumns,
        );
        final logoSize = searchGridLogoSizeForCellWidth(cellWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kSearchFavoritesGridColumns,
            mainAxisSpacing: kSearchGridSpacing,
            crossAxisSpacing: kSearchGridSpacing,
            childAspectRatio: kSearchGridChildAspectRatio,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            return SearchCompactAssetCard(
              asset: asset,
              logoSize: logoSize,
              onTap: () => onAssetTap(asset),
            );
          },
        );
      },
    );
  }
}
