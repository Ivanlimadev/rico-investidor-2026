import 'package:flutter/material.dart';

enum MarketCategory {
  stocks('Stocks americanas', Icons.language),
  reits('REITs', Icons.domain),
  cripto('Criptomoedas', Icons.currency_bitcoin);

  const MarketCategory(this.title, this.icon);

  final String title;
  final IconData icon;
}
