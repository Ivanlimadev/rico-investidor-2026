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

  /// Fundo escuro e quente dos cards de mercado.
  final List<Color> cardGradient;
  final Color accentColor;
  final Color? iconAccent;

  Color get glowColor => accentColor;
}

extension MarketCategoryThemeX on MarketCategory {
  MarketCategoryTheme get theme {
    switch (this) {
      case MarketCategory.acoesBr:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.brazilFlag,
          shortLabel: 'Ações BR',
          accentColor: Color(0xFFFF6B35),
          cardGradient: [Color(0xFF3D1810), Color(0xFF1F0C08)],
        );
      case MarketCategory.fiis:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.fiiBuilding,
          shortLabel: 'FIIs',
          accentColor: Color(0xFFFFB347),
          iconAccent: Color(0xFFFFD180),
          cardGradient: [Color(0xFF3D2A12), Color(0xFF1F1508)],
        );
      case MarketCategory.cripto:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.bitcoin,
          shortLabel: 'Cripto',
          accentColor: Color(0xFFFF8C42),
          cardGradient: [Color(0xFF3D220F), Color(0xFF1F1006)],
        );
      case MarketCategory.bdr:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.globe,
          shortLabel: 'BDRs',
          accentColor: Color(0xFFE85D75),
          iconAccent: Color(0xFFFF8A9B),
          cardGradient: [Color(0xFF3D1520), Color(0xFF1F0A10)],
        );
      case MarketCategory.etf:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.chartBr,
          shortLabel: 'ETFs BR',
          accentColor: Color(0xFFE8A838),
          iconAccent: Color(0xFFFFD166),
          cardGradient: [Color(0xFF352810), Color(0xFF1A1406)],
        );
      case MarketCategory.stocks:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.usFlag,
          shortLabel: 'Stocks EUA',
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
      case MarketCategory.moeda:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.forex,
          shortLabel: 'Moedas',
          accentColor: Color(0xFFFF9F68),
          iconAccent: Color(0xFFFFC9A8),
          cardGradient: [Color(0xFF3D1F14), Color(0xFF1F0E08)],
        );
      case MarketCategory.indices:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.indices,
          shortLabel: 'Índices',
          accentColor: Color(0xFFFFB84D),
          iconAccent: Color(0xFFFFD98E),
          cardGradient: [Color(0xFF332410), Color(0xFF181004)],
        );
      case MarketCategory.etfInternacional:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.chartGlobal,
          shortLabel: 'ETF Intl.',
          accentColor: Color(0xFFFF6F91),
          iconAccent: Color(0xFFFF9EB6),
          cardGradient: [Color(0xFF351820), Color(0xFF1A0C10)],
        );
      case MarketCategory.tesouroDireto:
        return const MarketCategoryTheme(
          iconKind: MarketCategoryIconKind.treasury,
          shortLabel: 'Tesouro',
          accentColor: Color(0xFF5EC4A8),
          iconAccent: Color(0xFF9AE4C8),
          cardGradient: [Color(0xFF142820), Color(0xFF081410)],
        );
    }
  }
}
