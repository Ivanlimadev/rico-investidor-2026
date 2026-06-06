import 'package:flutter/material.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/features/portfolio/widgets/add_asset_circle_card.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Grid 3 colunas com mini cards circulares — máx. 12 ativos por seção.
class AddAssetCircleGrid extends StatelessWidget {
  const AddAssetCircleGrid({
    super.key,
    required this.assets,
    required this.onAssetTap,
    this.maxItems = kMaxSearchFavoritesDisplay,
  });

  final List<AssetItem> assets;
  final ValueChanged<AssetItem> onAssetTap;
  final int maxItems;

  static const _columns = kSearchFavoritesGridColumns;

  /// Cards mais altos que o grid da busca — logo circular + ticker + preço.
  static const _childAspectRatio = 0.82;

  @override
  Widget build(BuildContext context) {
    final visible = assets.take(maxItems).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = searchGridCellWidth(
          gridWidth: constraints.maxWidth,
          columns: _columns,
        );
        final logoSize = searchGridLogoSizeForCellWidth(cellWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisSpacing: kSearchGridSpacing,
            crossAxisSpacing: kSearchGridSpacing,
            childAspectRatio: _childAspectRatio,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final asset = visible[index];
            return AddAssetCircleAssetCard(
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
