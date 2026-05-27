import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/crypto/data/crypto_depth_stream.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoLiveOrderBookCard extends StatefulWidget {
  const CryptoLiveOrderBookCard({
    super.key,
    required this.symbol,
    required this.initialBook,
  });

  final String symbol;
  final CryptoOrderBookDto initialBook;

  @override
  State<CryptoLiveOrderBookCard> createState() => _CryptoLiveOrderBookCardState();
}

class _CryptoLiveOrderBookCardState extends State<CryptoLiveOrderBookCard> {
  CryptoDepthStream? _stream;
  late CryptoOrderBookDto _book;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    _book = widget.initialBook;
    _stream = CryptoDepthStream(
      symbol: widget.symbol,
      onBook: (book) {
        if (!mounted) return;
        setState(() {
          _book = book;
          _live = true;
        });
      },
    )..connect();
  }

  @override
  void dispose() {
    _stream?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Livro de ofertas', style: Theme.of(context).textTheme.titleSmall),
                if (_live) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.positive, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ao vivo',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.positive,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Side(title: 'Compra (bid)', levels: _book.bids, isBid: true)),
                const SizedBox(width: 12),
                Expanded(child: _Side(title: 'Venda (ask)', levels: _book.asks, isBid: false)),
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
    final maxQty = levels.isEmpty ? 0.0 : levels.map((level) => level.quantity).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (levels.isEmpty)
          Text('—', style: Theme.of(context).textTheme.bodySmall)
        else
          for (final level in levels.take(10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Stack(
                children: [
                  if (maxQty > 0)
                    FractionallySizedBox(
                      widthFactor: (level.quantity / maxQty).clamp(0.05, 1.0),
                      alignment: isBid ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: (isBid ? Colors.green : Colors.red).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  Row(
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
                ],
              ),
            ),
      ],
    );
  }
}
