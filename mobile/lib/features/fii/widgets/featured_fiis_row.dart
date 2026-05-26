import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_screener_presets.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class FeaturedFiisRow extends StatelessWidget {
  const FeaturedFiisRow({super.key, required this.repository});

  final FiiRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FiiScreenerItem>>(
      future: repository.featuredFiis(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _FeaturedFiisList(
            items: featuredFiisOfflineFallback,
            repository: repository,
          );
        }

        return _FeaturedFiisList(
          items: snapshot.data!,
          repository: repository,
        );
      },
    );
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
    return SizedBox(
      width: 168,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.ticker, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (item.closePrice != null)
                  Text(formatBrl(item.closePrice!), style: Theme.of(context).textTheme.titleSmall),
                if (item.dividendYieldTtm != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'DY ${formatPct(item.dividendYieldTtm!)}',
                    style: TextStyle(color: AppColors.positive, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
                if (item.pvp != null)
                  Text('P/VP ${item.pvp!.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
