import 'package:flutter/material.dart';
import 'package:rico_investidor/features/home/widgets/market_category_icon.dart';
import 'package:rico_investidor/models/market_category_icon_kind.dart';

/// Card para explorar o mercado de criptomoedas.
class CryptoMarketHubCard extends StatelessWidget {
  const CryptoMarketHubCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                colors: [Color(0xFF3A2A12), Color(0xFF1C1206)],
              ),
              border: Border.all(color: const Color(0xFFF7A23B).withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const MarketCategoryIcon(
                    kind: MarketCategoryIconKind.bitcoin,
                    size: 52,
                    accentColor: Color(0xFFF7A23B),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mercado de cripto',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFF6EC),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bitcoin, Ethereum e as principais criptomoedas',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFF3D9BC),
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explorar criptos',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: const Color(0xFFF7B968),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFFF7B968).withValues(alpha: 0.9),
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
