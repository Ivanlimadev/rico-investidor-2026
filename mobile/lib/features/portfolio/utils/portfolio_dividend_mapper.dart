import 'package:rico_investidor/features/fii/utils/fii_simulation.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

List<DividendPayment> mapDistributionPaymentsToPortfolio({
  required PortfolioHolding holding,
  required Iterable<FiiDistributionPayment> payments,
  required DateTime cutoff,
  String defaultKind = 'Provento',
}) {
  final results = <DividendPayment>[];

  for (final payment in payments) {
    final date = parseFiiDate(payment.paymentDate ?? payment.referenceDate);
    final perShare = payment.valuePerShare;
    if (date == null || perShare == null || perShare <= 0) continue;

    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(cutoff)) continue;

    final total = perShare * holding.quantity;
    if (total <= 0) continue;

    results.add(
      DividendPayment(
        id: _syncId(holding.symbol, day),
        symbol: holding.symbol,
        name: holding.name,
        amount: total,
        date: day,
        kind: payment.label?.trim().isNotEmpty == true ? payment.label!.trim() : defaultKind,
        amountPerShare: perShare,
      ),
    );
  }

  return results;
}

String _syncId(String symbol, DateTime date) {
  return 'sync-${symbol.toUpperCase()}-${date.toIso8601String().split('T').first}';
}

String monthNamePt(int month) {
  const labels = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return labels[month.clamp(1, 12) - 1];
}

String formatDividendDay(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
