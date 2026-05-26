import 'package:flutter/material.dart';
import 'package:rico_investidor/features/home/widgets/market_category_icon.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_theme.dart';

/// Card quadrado estilo iOS — fundo escuro quente e ícones em destaque.
class MarketCategoryCard extends StatelessWidget {
  const MarketCategoryCard({
    super.key,
    required this.category,
    required this.assetCount,
    required this.onTap,
  });

  final MarketCategory category;
  final int assetCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = category.theme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: visual.cardGradient,
            ),
            border: Border.all(
              color: visual.accentColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: visual.accentColor.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MarketCategoryIcon(
                  kind: visual.iconKind,
                  size: 46,
                  iconColor: visual.iconAccent,
                  accentColor: visual.accentColor,
                ),
                const SizedBox(height: 9),
                Text(
                  visual.shortLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontSize: 11.5,
                    color: const Color(0xFFFFF5EE),
                    shadows: [
                      Shadow(
                        color: visual.accentColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$assetCount ativos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFE0CC).withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
