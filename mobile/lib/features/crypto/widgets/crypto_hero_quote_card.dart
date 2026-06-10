import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoHeroQuoteCard extends StatelessWidget {
  const CryptoHeroQuoteCard({
    super.key,
    required this.symbol,
    required this.name,
    required this.price,
    required this.currency,
    required this.changePercent,
    this.logoUrl,
    this.brlPrice,
    this.showBrazilianQuotes = false,
    this.streamLive = false,
    this.marketCap,
  });

  final String symbol;
  final String name;
  final double price;
  final String currency;
  final double changePercent;
  final String? logoUrl;
  final double? brlPrice;
  final bool showBrazilianQuotes;
  final bool streamLive;
  final double? marketCap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final positive = changePercent >= 0;
    final changeColor = positive ? AppColors.positive : AppColors.negative;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AssetLogo(
                  symbol: symbol,
                  logoUrl: logoUrl,
                  size: kAssetLogoSizeList,
                  borderRadius: kAssetLogoBorderRadius,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        symbol,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                      ),
                      if (name.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: onSurface.withValues(alpha: 0.75),
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              streamLive ? 'Cotação ao vivo (USD)' : 'Cotação 24h (USD)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              formatCryptoPrice(price, currency: currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
            ),
            if (showBrazilianQuotes && brlPrice != null) ...[
              const SizedBox(height: 4),
              Text(
                formatCryptoPrice(brlPrice!, currency: 'BRL'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        positive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: changeColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${positive ? '+' : ''}${changePercent.toStringAsFixed(2)}% 24h',
                        style: TextStyle(color: changeColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (streamLive)
                  Chip(
                    label: const Text('Ao vivo'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (marketCap != null && marketCap! > 0)
                  _MetricChip(label: 'Cap', value: _compactUsd(marketCap!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _compactUsd(double value) {
    if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(1)}M';
    return '\$${value.toStringAsFixed(0)}';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
