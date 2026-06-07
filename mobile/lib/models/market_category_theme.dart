import 'package:flutter/material.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_icon_kind.dart';

class MarketCategoryTheme {
  const MarketCategoryTheme({
    required this.iconKind,
    required this.shortLabel,
    required this.cardGradient,
    required this.accentColor,
    this.iconAccent,
  });

  final MarketCategoryIconKind iconKind;
  final String shortLabel;
  final List<Color> cardGradient;
  final Color accentColor;
  final Color? iconAccent;

  Color get glowColor => accentColor;
}

extension MarketCategoryThemeX on MarketCategory {
  MarketCategoryTheme get theme {
    switch (this) {
      case MarketCategory.stocks:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.usFlag,
          shortLabel: 'Stocks',
          accentColor: Color(0xFFFF5C5C),
          cardGradient: [Color(0xFF2A1218), Color(0xFF14080C)],
        );
      case MarketCategory.reits:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.reits,
          shortLabel: 'REITs',
          accentColor: Color(0xFFFF7EB3),
          iconAccent: Color(0xFFFFB3D0),
          cardGradient: [Color(0xFF3D1428), Color(0xFF1F0A14)],
        );
      case MarketCategory.cripto:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.bitcoin,
          shortLabel: 'Cripto',
          accentColor: Color(0xFFFF8C42),
          cardGradient: [Color(0xFF3D220F), Color(0xFF1F1006)],
        );
    }
  }
}
