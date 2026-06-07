import 'package:rico_investidor/core/utils/dividend_payment_mappers.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/market_series_models.dart';

int? dividendPaymentBucketYear(String? paymentDate, String? referenceDate) {
  for (final raw in [paymentDate, referenceDate]) {
    if (raw == null || raw.length < 4) continue;
    final year = int.tryParse(raw.substring(0, 4));
    if (year != null) return year;
  }
  return null;
}

double _roundPerShareTotal(double value) => double.parse(value.toStringAsFixed(4));

/// Soma dos proventos por ação/cota em cada ano (ano do pagamento, ou referência).
List<DistributionYear> buildAnnualDividendSummaryFromPayments(
  List<DistributionPayment> payments,
) {
  final byYear = <int, List<double>>{};

  for (final payment in payments) {
    final value = payment.valuePerShare;
    if (value == null || value <= 0) continue;
    final year = dividendPaymentBucketYear(payment.paymentDate, payment.referenceDate);
    if (year == null) continue;
    byYear.putIfAbsent(year, () => []).add(value);
  }

  return byYear.entries
      .map(
        (entry) => DistributionYear(
          year: entry.key,
          totalPerShare: _roundPerShareTotal(entry.value.fold(0.0, (sum, v) => sum + v)),
          payments: entry.value.length,
        ),
      )
      .toList();
}

List<DistributionYear> buildAnnualDividendSummaryFromGlobal(
  List<GlobalStockDividendDto> dividends,
) {
  return buildAnnualDividendSummaryFromPayments(paymentsFromGlobalDividends(dividends));
}

/// Recalcula a partir dos pagamentos quando disponível; senão usa o resumo da API.
List<DistributionYear> resolveAnnualDividendSummary({
  required List<DistributionYear> annualSummary,
  List<DistributionPayment> payments = const [],
  List<GlobalStockDividendDto> globalDividends = const [],
}) {
  if (globalDividends.isNotEmpty) {
    final computed = buildAnnualDividendSummaryFromGlobal(globalDividends);
    if (computed.isNotEmpty) return computed;
  }
  if (payments.isNotEmpty) {
    final computed = buildAnnualDividendSummaryFromPayments(payments);
    if (computed.isNotEmpty) return computed;
  }
  return annualSummary;
}
