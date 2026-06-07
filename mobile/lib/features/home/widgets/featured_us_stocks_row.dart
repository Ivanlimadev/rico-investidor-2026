import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/quote_refresh_timer.dart';
import 'package:rico_investidor/core/widgets/featured_card_skeleton.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/home/widgets/featured_asset_card.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class FeaturedUsStocksRow extends StatefulWidget {
  const FeaturedUsStocksRow({
    super.key,
    required this.repository,
    this.initialItems,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final GlobalMarketRepository repository;
  final List<AssetItem>? initialItems;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  State<FeaturedUsStocksRow> createState() => _FeaturedUsStocksRowState();
}

class _FeaturedUsStocksRowState extends State<FeaturedUsStocksRow> {
  late Future<List<AssetItem>>? _loadFuture;
  QuoteRefreshTimer? _refreshTimer;
  List<AssetItem> _liveItems = const [];

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.initialItems == null ? widget.repository.listFeaturedUsAssets() : null;
    _configureAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.stop();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeaturedUsStocksRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != null && oldWidget.initialItems == null) {
      _loadFuture = null;
    }
  }

  Future<void> _configureAutoRefresh() async {
    _refreshTimer?.stop();
    if (widget.initialItems != null) return;
    try {
      final caps = await widget.repository.getCapabilities();
      if (!caps.realtimeEnabled) return;
      _refreshTimer = QuoteRefreshTimer(
        onTick: () async {
          widget.repository.invalidateFeaturedCache();
          final items = await widget.repository.listFeaturedUsAssets();
          if (!mounted) return;
          setState(() => _liveItems = items);
        },
      )..start(refreshSeconds: caps.refreshSeconds ?? 60, enabled: true);
    } catch (_) {}
  }

  Future<void> _retry() async {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }
    widget.repository.invalidateFeaturedCache();
    setState(() {
      _loadFuture = widget.repository.listFeaturedUsAssets();
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

    if (_liveItems.isNotEmpty) {
      return _buildContent(context, _liveItems, null);
    }

    return FutureBuilder<List<AssetItem>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FeaturedRowSkeleton();
        }
        final items = snapshot.data ?? const <AssetItem>[];
        if (items.isNotEmpty && _liveItems.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _liveItems = items);
          });
        }
        return _buildContent(
          context,
          _liveItems.isNotEmpty ? _liveItems : items,
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
            message: 'Não foi possível carregar as ações americanas.',
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
        message: 'Destaques do mercado americano indisponíveis no momento.',
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => FeaturedAssetCard(
          asset: items[index],
          onTap: () => openAssetDetail(
            context,
            asset: items[index],
          ),
        ),
      ),
    );
  }
}
