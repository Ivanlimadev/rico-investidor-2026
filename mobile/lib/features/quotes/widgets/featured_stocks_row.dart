import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/featured_card_skeleton.dart';
import 'package:rico_investidor/features/home/widgets/featured_asset_card.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/models/asset_item.dart';

class FeaturedStocksRow extends StatefulWidget {
  const FeaturedStocksRow({
    super.key,
    required this.repository,
    required this.fiiRepository,
    this.initialItems,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final QuoteRepository repository;
  final FiiRepository fiiRepository;
  final List<AssetItem>? initialItems;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  State<FeaturedStocksRow> createState() => _FeaturedStocksRowState();
}

class _FeaturedStocksRowState extends State<FeaturedStocksRow> {
  late Future<List<AssetItem>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.initialItems == null ? widget.repository.featuredStocks() : null;
  }

  @override
  void didUpdateWidget(covariant FeaturedStocksRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != null && oldWidget.initialItems == null) {
      _loadFuture = null;
    }
  }

  Future<void> _retry() async {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }
    widget.repository.invalidateFeaturedCache();
    setState(() {
      _loadFuture = widget.repository.featuredStocks();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.initialItems == null) {
      return const FeaturedRowSkeleton();
    }

    if (widget.error != null && widget.initialItems == null) {
      return _buildContent(context, const <AssetItem>[], widget.error);
    }

    if (widget.initialItems != null) {
      return _buildContent(context, widget.initialItems!, widget.error);
    }

    return FutureBuilder<List<AssetItem>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FeaturedRowSkeleton();
        }
        return _buildContent(
          context,
          snapshot.data ?? const <AssetItem>[],
          snapshot.hasError ? snapshot.error : null,
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, List<AssetItem> items, Object? error) {
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DataUnavailableBanner(
            message: 'Não foi possível carregar as principais ações.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return const DataUnavailableBanner(
        message: 'Nenhuma ação em destaque disponível no momento.',
      );
    }

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
            fiiRepository: widget.fiiRepository,
            quoteRepository: widget.repository,
          ),
        ),
      ),
    );
  }
}
