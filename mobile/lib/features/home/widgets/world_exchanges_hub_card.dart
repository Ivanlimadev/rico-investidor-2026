import 'package:flutter/material.dart';
import 'package:rico_investidor/features/home/widgets/market_category_icon.dart';
import 'package:rico_investidor/models/market_category_icon_kind.dart';

/// Card de entrada para o mercado americano.
class WorldExchangesHubCard extends StatelessWidget {
  const WorldExchangesHubCard({
    super.key,
    required this.onTap,
    this.totalExchanges,
  });

  final VoidCallback onTap;
  final int? totalExchanges;

  @override
  Widget build(BuildContext context) {
    const countLabel = 'Mercado Americano';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                colors: [Color(0xFF2A2248), Color(0xFF151024)],
              ),
              border: Border.all(color: const Color(0xFF9B8CFF).withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const MarketCategoryIcon(
                    kind: MarketCategoryIconKind.globe,
                    size: 52,
                    accentColor: Color(0xFF9B8CFF),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mercado Americano',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF8F5FF),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ações e REITs na NYSE e NASDAQ',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFCFC4FF),
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          countLabel,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: const Color(0xFFB5A6FF),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFFB5A6FF).withValues(alpha: 0.9),
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
