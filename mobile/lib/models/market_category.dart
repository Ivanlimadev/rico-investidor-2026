import 'package:flutter/material.dart';

enum MarketCategory {
  acoesBr('Ações brasileiras', Icons.show_chart),
  fiis('FIIs', Icons.apartment),
  cripto('Criptomoedas', Icons.currency_bitcoin),
  bdr('BDRs', Icons.public),
  etf('ETFs Brasil', Icons.pie_chart_outline),
  stocks('Stocks (EUA)', Icons.language),
  reits('REITs', Icons.domain),
  moeda('Moedas', Icons.currency_exchange),
  indices('Índices', Icons.insights),
  etfInternacional('ETFs internacionais', Icons.candlestick_chart),
  tesouroDireto('Tesouro Direto', Icons.account_balance);

  const MarketCategory(this.title, this.icon);

  final String title;
  final IconData icon;
}
