import 'package:flutter/material.dart';
import 'package:rico_investidor/features/home/widgets/market_category_icon.dart';
import 'package:rico_investidor/models/market_category_icon_kind.dart';

/// Card de entrada para o hub dos EUA na Home.
class UsMarketHubCard extends StatelessWidget {
  const UsMarketHubCard({
    super.key,
    required this.onTap,
    this.totalAssets,
    this.categoryCount = 2,
  });

  final VoidCallback onTap;
  final int? totalAssets;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    const countLabel = 'NYSE e NASDAQ';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF102A4C), Color(0xFF081526)],
              ),
              border: Border.all(color: const Color(0xFF4DA3FF).withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4DA3FF).withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const MarketCategoryIcon(
                    kind: MarketCategoryIconKind.usFlag,
                    size: 52,
                    accentColor: Color(0xFF4DA3FF),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bolsa Americana',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF5FAFF),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ações e REITs americanas — cotações em tempo real (Business)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFB8D4F0),
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          countLabel,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF7BC0FF),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFF7BC0FF).withValues(alpha: 0.9),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
