import 'package:flutter/material.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoFundamentalsCard extends StatelessWidget {
  const CryptoFundamentalsCard({
    super.key,
    required this.fundamentals,
    this.brl,
    this.showBrazilianQuotes = false,
  });

  final CryptoFundamentalsDto fundamentals;
  final CryptoBrlSnapshotDto? brl;
  final bool showBrazilianQuotes;

  @override
  Widget build(BuildContext context) {
    final rows = <_FundRow>[
      if (fundamentals.marketCap != null)
        _FundRow('Market cap', formatCryptoVolume(fundamentals.marketCap!)),
      if (fundamentals.marketCapRank != null)
        _FundRow('Rank global', '#${fundamentals.marketCapRank}'),
      if (showBrazilianQuotes && brl?.price != null)
        _FundRow('Preço BRL', formatCryptoPrice(brl!.price!, currency: 'BRL')),
      if (fundamentals.circulatingSupply != null)
        _FundRow('Oferta circulante', _formatSupply(fundamentals.circulatingSupply!)),
      if (fundamentals.ath != null)
        _FundRow(
          'ATH (USD)',
          '${formatCryptoPrice(fundamentals.ath!)}'
          '${fundamentals.athChangePercent != null ? ' (${fundamentals.athChangePercent!.toStringAsFixed(1)}%)' : ''}',
        ),
      if (fundamentals.atl != null) _FundRow('ATL (USD)', formatCryptoPrice(fundamentals.atl!)),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fundamentos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _FundTile(row: rows[i]),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSupply(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(2)}K';
    return value.toStringAsFixed(0);
  }
}

class _FundRow {
  const _FundRow(this.label, this.value);

  final String label;
  final String value;
}

class _FundTile extends StatelessWidget {
  const _FundTile({required this.row});

  final _FundRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            row.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
        ),
        Flexible(
          child: Text(
            row.value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
