import 'package:rico_investidor/features/fii/utils/fii_payments.dart';
import 'package:rico_investidor/models/fii_models.dart';

/// Data do último pregão com cotação válida.
String? latestQuoteTradeDate(List<FiiCandleBar> candles) {
  if (candles.isEmpty) return null;

  final sorted = List<FiiCandleBar>.from(candles)
    ..sort((a, b) => b.tradeDate.compareTo(a.tradeDate));

  for (final bar in sorted) {
    if (bar.close > 0) return bar.tradeDate;
  }
  return null;
}

String formatCvmReportReference(String? raw) => formatReferenceMonth(raw);

String cvmReportReferenceLabel(String? raw) {
  final formatted = formatCvmReportReference(raw);
  if (formatted == '—') return formatted;
  return 'Referência do relatório (CVM): $formatted';
}

String quoteUpdatedLabel(String? tradeDate) {
  final formatted = formatPaymentDate(tradeDate);
  if (formatted == '—') return formatted;
  return 'Cotação atualizada em $formatted (último pregão)';
}
