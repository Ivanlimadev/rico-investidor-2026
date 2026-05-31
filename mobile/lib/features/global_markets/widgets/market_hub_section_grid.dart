import 'package:flutter/material.dart';
import 'package:rico_investidor/features/global_markets/widgets/country_hub_mini_asset_card.dart';
import 'package:rico_investidor/models/asset_item.dart';

class MarketHubSectionData {
  const MarketHubSectionData({
    required this.id,
    required this.title,
    required this.assets,
  });

  final String id;
  final String title;
  final List<AssetItem> assets;
}

class MarketHubSectionGrid extends StatelessWidget {
  const MarketHubSectionGrid({
    super.key,
    required this.section,
    required this.onAssetTap,
    this.logoSize = 28,
  });

  final MarketHubSectionData section;
  final ValueChanged<AssetItem> onAssetTap;
  final double logoSize;

  static bool usesMiniGrid(String sectionId) {
    return sectionId == 'featured' || sectionId == 'gainers' || sectionId == 'losers';
  }

  static int gridColumns(String sectionId) {
    if (sectionId == 'featured') return 5;
    return 4;
  }

  static int maxItems(String sectionId) {
    switch (sectionId) {
      case 'featured':
        return 35;
      case 'gainers':
      case 'losers':
        return 8;
      default:
        return 6;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (section.assets.isEmpty) return const SizedBox.shrink();

    final assets = section.assets.take(maxItems(section.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (usesMiniGrid(section.id))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Builder(
              builder: (context) {
                final isFeatured = section.id == 'featured';
                final cardLogoSize = isFeatured ? 28.0 : logoSize;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns(section.id),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: isFeatured
                        ? 0.70
                        : (logoSize >= 36 ? 0.64 : 0.82),
                  ),
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return CountryHubMiniAssetCard(
                      asset: asset,
                      logoSize: cardLogoSize,
                      binanceStyle: isFeatured,
                      onTap: () => onAssetTap(asset),
                    );
                  },
                );
              },
            ),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              scrollDirection: Axis.horizontal,
              itemCount: assets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final asset = assets[index];
                return SizedBox(
                  width: 96,
                  child: CountryHubMiniAssetCard(
                    asset: asset,
                    logoSize: logoSize,
                    onTap: () => onAssetTap(asset),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
