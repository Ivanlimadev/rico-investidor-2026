import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/services/favorites_storage.dart';

/// Favoritos na carteira — ordenados pela maior queda do dia.
class PortfolioFavoritesGadget extends StatefulWidget {
  const PortfolioFavoritesGadget({
    super.key,
    required this.searchService,
  });

  final AssetSearchService searchService;

  @override
  PortfolioFavoritesGadgetState createState() => PortfolioFavoritesGadgetState();
}

class PortfolioFavoritesGadgetState extends State<PortfolioFavoritesGadget> {
  List<AssetItem> _items = [];
  bool _loading = true;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    reload();
    _subscription = favoritesStorage.changes.listen((_) => reload());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final stored = await favoritesStorage.load();
    final refreshed = <AssetItem>[];

    for (final item in stored) {
      try {
        final live = await widget.searchService
            .findBySymbolAsync(item.symbol)
            .timeout(const Duration(seconds: 12), onTimeout: () => null);
        refreshed.add(live ?? item);
      } catch (_) {
        refreshed.add(item);
      }
    }

    refreshed.sort((a, b) => a.changePercent.compareTo(b.changePercent));

    if (!mounted) return;
    setState(() {
      _items = refreshed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.star_border_rounded,
                  color: AppColors.accent.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use a estrela nos ativos para favoritar — aparecem aqui, '
                    'ordenados pela maior queda.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Favoritos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Maior desvalorização primeiro',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                          ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: _items.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final asset = _items[index];
                    return _FavoriteAssetTile(
                      asset: asset,
                      onTap: () => openAssetDetail(
                        context,
                        asset: asset,
                      ),
                      onRemove: () => favoritesStorage.remove(asset.symbol),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FavoriteAssetTile extends StatelessWidget {
  const _FavoriteAssetTile({
    required this.asset,
    required this.onTap,
    required this.onRemove,
  });

  final AssetItem asset;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final changeColor = asset.isPositive ? AppColors.positive : AppColors.negative;
    final logoUrl = asset.logoUrl;

    return SizedBox(
      width: 132,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onRemove,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AssetLogo(
                      symbol: asset.symbol,
                      logoUrl: logoUrl,
                      size: 34,
                      borderRadius: 9,
                    ),
                    const Spacer(),
                    Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  asset.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  _formatFavoritePrice(asset),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      asset.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: changeColor,
                      size: 18,
                    ),
                    Expanded(
                      child: Text(
                        '${asset.changePercent >= 0 ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}

String _formatFavoritePrice(AssetItem asset) {
  if (asset.price <= 0) return '—';
  return switch (asset.category) {
    MarketCategory.stocks || MarketCategory.reits => formatUsd(asset.price),
    MarketCategory.cripto => formatCryptoPrice(asset.price),
  };
}
