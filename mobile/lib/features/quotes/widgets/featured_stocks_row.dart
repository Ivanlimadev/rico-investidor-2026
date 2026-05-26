import 'package:flutter/material.dart';
import 'package:rico_investidor/data/mock_market_data.dart';
import 'package:rico_investidor/features/home/widgets/featured_asset_card.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/models/asset_item.dart';

class FeaturedStocksRow extends StatelessWidget {
  const FeaturedStocksRow({
    super.key,
    required this.repository,
    required this.fiiRepository,
  });

  final QuoteRepository repository;
  final FiiRepository fiiRepository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AssetItem>>(
      future: repository.featuredStocks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.hasData && snapshot.data!.isNotEmpty
            ? snapshot.data!
            : MockMarketData.byCategory(
                MockMarketData.featured.first.category,
              ).take(4).toList();

        return SizedBox(
          height: 200,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => FeaturedAssetCard(
              asset: items[index],
              onTap: () => openAssetDetail(
                context,
                asset: items[index],
                fiiRepository: fiiRepository,
                quoteRepository: repository,
              ),
            ),
          ),
        );
      },
    );
  }
}
