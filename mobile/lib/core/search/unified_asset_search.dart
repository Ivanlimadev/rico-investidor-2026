import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

/// Debounce + cancelamento para busca global em qualquer tela.
class UnifiedAssetSearchSnapshot {
  const UnifiedAssetSearchSnapshot._({
    required this.query,
    required this.loading,
    required this.results,
  });

  const UnifiedAssetSearchSnapshot.idle()
      : query = '',
        loading = false,
        results = const [];

  const UnifiedAssetSearchSnapshot.loading(this.query)
      : loading = true,
        results = const [];

  const UnifiedAssetSearchSnapshot.done({
    required this.query,
    required this.results,
  }) : loading = false;

  final String query;
  final bool loading;
  final List<AssetItem> results;

  bool get active => unifiedSearchActive(query);
}

typedef UnifiedAssetSearchListener = void Function(UnifiedAssetSearchSnapshot snapshot);

class UnifiedAssetSearchRunner {
  UnifiedAssetSearchRunner({AssetSearchService? searchService})
      : _searchService = searchService ?? assetSearchService;

  final AssetSearchService _searchService;
  Timer? _debounce;
  int _generation = 0;

  void search(
    String rawQuery,
    UnifiedAssetSearchListener listener, {
    MarketPreference? preferredMarket,
  }) {
    _debounce?.cancel();
    final query = rawQuery.trim();

    if (!unifiedSearchActive(query)) {
      listener(const UnifiedAssetSearchSnapshot.idle());
      return;
    }

    listener(UnifiedAssetSearchSnapshot.loading(query));

    _debounce = Timer(kAssetSearchDebounce, () async {
      final generation = ++_generation;
      final results = await _searchService.searchAsync(
        query,
        preferredMarket: preferredMarket,
      );
      if (generation != _generation) return;
      listener(UnifiedAssetSearchSnapshot.done(query: query, results: results));
    });
  }

  void dispose() {
    _debounce?.cancel();
    _generation++;
  }
}

class UnifiedAssetResultsBody extends StatelessWidget {
  const UnifiedAssetResultsBody({
    super.key,
    required this.snapshot,
    required this.fiiRepository,
    required this.quoteRepository,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });

  final UnifiedAssetSearchSnapshot snapshot;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (snapshot.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nenhum resultado para "${snapshot.query}".',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: padding,
      itemCount: snapshot.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final asset = snapshot.results[index];
        return UnifiedAssetResultTile(
          asset: asset,
          onTap: () => openAssetDetail(
            context,
            asset: asset,
            fiiRepository: fiiRepository,
            quoteRepository: quoteRepository,
          ),
        );
      },
    );
  }
}

class UnifiedAssetResultTile extends StatelessWidget {
  const UnifiedAssetResultTile({
    super.key,
    required this.asset,
    required this.onTap,
  });

  final AssetItem asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priceLabel = _formatPrice(asset);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AssetSearchLeading(asset: asset, logoSize: kAssetLogoSizeCompact),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.symbol,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (asset.name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        asset.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (priceLabel != null)
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  Chip(
                    label: Text(
                      asset.category.title,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatPrice(AssetItem asset) {
    if (asset.price <= 0) return null;
    return switch (asset.category) {
      MarketCategory.stocks || MarketCategory.reits => formatUsd(asset.price),
      MarketCategory.cripto => formatCryptoPrice(asset.price),
      MarketCategory.moeda => asset.price.toStringAsFixed(4),
      _ => formatBrl(asset.price),
    };
  }
}
