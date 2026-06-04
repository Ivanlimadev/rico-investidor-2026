import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/quote_sparkline.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Conteúdo da linha (ticker + mini-gráfico + preço) — reutilizável dentro de cards maiores.
class QuoteMarketListRow extends StatelessWidget {
  const QuoteMarketListRow({
    super.key,
    required this.asset,
    this.formatPrice = formatUsd,
  });

  final AssetItem asset;
  final String Function(double value) formatPrice;

  @override
  Widget build(BuildContext context) {
    final positive = asset.changePercent >= 0;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: AssetCardHeader(
            symbol: asset.symbol,
            name: asset.name,
            logoUrl: asset.logoUrl,
            logoSize: kAssetLogoSizeCompact,
            nameMaxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        QuoteSparkline(
          values: asset.sparkline,
          positive: positive,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatPrice(asset.price),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            QuoteChangeBadge(
              changePercent: asset.changePercent,
              positive: positive,
            ),
          ],
        ),
      ],
    );
  }
}

/// Linha de lista com mini-gráfico (estilo Twelve Data).
class UsMarketQuoteListTile extends StatelessWidget {
  const UsMarketQuoteListTile({
    super.key,
    required this.asset,
    required this.onTap,
    this.formatPrice = formatUsd,
  });

  final AssetItem asset;
  final VoidCallback onTap;
  final String Function(double value) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: QuoteMarketListRow(
            asset: asset,
            formatPrice: formatPrice,
          ),
        ),
      ),
    );
  }
}
