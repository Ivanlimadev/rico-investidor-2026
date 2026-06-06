import 'package:rico_investidor/models/holding_currency.dart';

class PortfolioSummary {
  const PortfolioSummary({
    required this.totalBalance,
    required this.monthlyDividends,
    required this.portfolioChangePercent,
    required this.dividendsVsLastMonthPercent,
    this.displayCurrency = HoldingCurrency.brl,
  });

  /// Patrimônio total da carteira (marcação a mercado).
  final double totalBalance;

  /// Proventos recebidos ou previstos no mês corrente.
  final double monthlyDividends;

  /// Variação percentual do patrimônio no período exibido.
  final double portfolioChangePercent;

  /// Variação dos dividendos em relação ao mês anterior.
  final double dividendsVsLastMonthPercent;

  final HoldingCurrency displayCurrency;

  bool get isPortfolioUp => portfolioChangePercent >= 0;
  bool get isDividendsUp => dividendsVsLastMonthPercent >= 0;
}
