import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/models/asset_item.dart';

class CryptoMoversSection extends StatelessWidget {
  const CryptoMoversSection({
    super.key,
    required this.movers,
    required this.onTap,
  });

  final CryptoMoversResponseDto movers;
  final ValueChanged<AssetItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (movers.gainers.isEmpty && movers.losers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 560;
          if (stacked) {
            return Column(
              children: [
                _MoverCard(
                  title: 'Maiores altas',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.positive,
                  items: movers.gainers,
                  onTap: onTap,
                ),
                const SizedBox(height: 8),
                _MoverCard(
                  title: 'Maiores baixas',
                  icon: Icons.trending_down_rounded,
                  color: AppColors.negative,
                  items: movers.losers,
                  onTap: onTap,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MoverCard(
                  title: 'Maiores altas',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.positive,
                  items: movers.gainers,
                  onTap: onTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MoverCard(
                  title: 'Maiores baixas',
                  icon: Icons.trending_down_rounded,
                  color: AppColors.negative,
                  items: movers.losers,
                  onTap: onTap,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MoverCard extends StatelessWidget {
  const _MoverCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<CryptoQuoteDto> items;
  final ValueChanged<AssetItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sem movimentos hoje',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              )
            else
              ...items.map(
                (quote) => _MoverRow(
                  quote: quote,
                  color: color,
                  onTap: () => onTap(quote.toAssetItem()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoverRow extends StatelessWidget {
  const _MoverRow({
    required this.quote,
    required this.color,
    required this.onTap,
  });

  final CryptoQuoteDto quote;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final changeText = '${quote.changePercent >= 0 ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AssetListLeading(symbol: quote.symbol, logoUrl: quote.imageUrl, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                quote.symbol,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              changeText,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
