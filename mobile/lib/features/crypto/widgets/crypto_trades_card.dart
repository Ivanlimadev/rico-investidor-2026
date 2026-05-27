import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoRecentTradesCard extends StatelessWidget {
  const CryptoRecentTradesCard({super.key, required this.trades});

  final CryptoRecentTradesDto trades;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Negócios recentes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (trades.trades.isEmpty)
              const Text('Sem trades recentes.')
            else
              for (final trade in trades.trades.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatCryptoPrice(trade.price),
                          style: TextStyle(
                            color: trade.isBuyerMaker ? AppColors.negative : AppColors.positive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        trade.quantity.toStringAsFixed(4),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
