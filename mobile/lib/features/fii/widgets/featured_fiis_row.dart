import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/core/widgets/featured_card_skeleton.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class FeaturedFiisRow extends StatefulWidget {
  const FeaturedFiisRow({
    super.key,
    required this.repository,
    this.initialItems,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final FiiRepository repository;
  final List<FiiScreenerItem>? initialItems;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  State<FeaturedFiisRow> createState() => _FeaturedFiisRowState();
}

class _FeaturedFiisRowState extends State<FeaturedFiisRow> {
  late Future<List<FiiScreenerItem>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.initialItems == null ? widget.repository.featuredFiis() : null;
  }

  @override
  void didUpdateWidget(covariant FeaturedFiisRow oldWidget) {
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
    widget.repository.invalidateFeatured();
    setState(() {
      _loadFuture = widget.repository.featuredFiis();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.initialItems == null) {
      return const FeaturedRowSkeleton();
    }

    if (widget.error != null && widget.initialItems == null) {
      return _buildContent(context, const <FiiScreenerItem>[], widget.error);
    }

    if (widget.initialItems != null) {
      return _buildContent(context, widget.initialItems!, widget.error);
    }

    return FutureBuilder<List<FiiScreenerItem>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FeaturedRowSkeleton();
        }
        return _buildContent(
          context,
          snapshot.data ?? const <FiiScreenerItem>[],
          snapshot.hasError ? snapshot.error : null,
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, List<FiiScreenerItem> items, Object? error) {
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DataUnavailableBanner(
            message: 'Não foi possível carregar os FIIs em destaque.',
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
        message: 'Nenhum FII em destaque disponível no momento.',
      );
    }

    return _FeaturedFiisList(items: items, repository: widget.repository);
  }
}

class _FeaturedFiisList extends StatelessWidget {
  const _FeaturedFiisList({
    required this.items,
    required this.repository,
  });

  final List<FiiScreenerItem> items;
  final FiiRepository repository;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _FeaturedFiiCard(
            item: items[index],
            onTap: () => openTickerDetailQuick(context, items[index].ticker),
          );
        },
      ),
    );
  }
}

class _FeaturedFiiCard extends StatelessWidget {
  const _FeaturedFiiCard({required this.item, required this.onTap});

  final FiiScreenerItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasDy = item.dividendYieldTtm != null;
    final hasPvp = item.pvp != null;

    return SizedBox(
      width: 168,
      height: 184,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AssetLogo(
                  symbol: item.ticker,
                  size: kAssetLogoSizeCard,
                  borderRadius: kAssetLogoBorderRadius,
                  style: AssetLogoStyle.standard,
                ),
                const SizedBox(height: 10),
                Text(
                  item.ticker,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                const Spacer(),
                if (item.closePrice != null)
                  Text(
                    formatBrl(item.closePrice!),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                if (hasDy || hasPvp) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (hasDy)
                        Text(
                          'DY ${formatPct(item.dividendYieldTtm!)}',
                          style: const TextStyle(
                            color: AppColors.positive,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      if (hasDy && hasPvp) const SizedBox(width: 8),
                      if (hasPvp)
                        Flexible(
                          child: Text(
                            'P/VP ${item.pvp!.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.2),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
