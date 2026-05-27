import 'package:flutter/material.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoOrderBookCard extends StatelessWidget {
  const CryptoOrderBookCard({super.key, required this.orderBook});

  final CryptoOrderBookDto orderBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Livro de ofertas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Side(title: 'Compra (bid)', levels: orderBook.bids, isBid: true)),
                const SizedBox(width: 12),
                Expanded(child: _Side(title: 'Venda (ask)', levels: orderBook.asks, isBid: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.title, required this.levels, required this.isBid});

  final String title;
  final List<CryptoOrderBookLevelDto> levels;
  final bool isBid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final level in levels.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatCryptoPrice(level.price),
                    style: TextStyle(
                      color: isBid ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  level.quantity.toStringAsFixed(4),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
