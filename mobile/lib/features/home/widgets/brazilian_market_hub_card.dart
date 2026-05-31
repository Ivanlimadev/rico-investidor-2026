import 'package:flutter/material.dart';
import 'package:rico_investidor/features/home/widgets/market_category_icon.dart';
import 'package:rico_investidor/models/market_category_icon_kind.dart';

/// Card de entrada para o hub Bolsa Brasileira na Home.
class BrazilianMarketHubCard extends StatelessWidget {
  const BrazilianMarketHubCard({
    super.key,
    required this.onTap,
    this.totalAssets,
    this.categoryCount = 7,
  });

  final VoidCallback onTap;
  final int? totalAssets;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final countLabel = totalAssets != null && totalAssets! > 0
        ? '$totalAssets ativos · $categoryCount categorias'
        : '$categoryCount categorias · B3 e mercado local';

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
                colors: [Color(0xFF1A3D24), Color(0xFF0D1F12)],
              ),
              border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.16),
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
                    kind: MarketCategoryIconKind.brazilFlag,
                    size: 52,
                    accentColor: Color(0xFF2ECC71),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bolsa Brasileira',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF4FFF8),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ações, FIIs, BDRs, ETFs, índices, moedas e Tesouro',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFB8E6C8),
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          countLabel,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF7DDFA3),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFF7DDFA3).withValues(alpha: 0.9),
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
