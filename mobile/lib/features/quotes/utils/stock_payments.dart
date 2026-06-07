import 'package:rico_investidor/core/utils/dividend_payment_format.dart';
import 'package:rico_investidor/models/market_series_models.dart';

List<DistributionPayment> sortStockPaymentsNewestFirst(List<DistributionPayment> payments) {
  return sortPaymentsNewestFirst(payments);
}

String stockPaymentDisplayType(DistributionPayment payment) {
  final label = payment.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  return 'Provento';
}

String stockPaymentComDate(DistributionPayment payment) {
  return formatPaymentDate(payment.referenceDate);
}

PaymentDateInfo stockPaymentDateInfo(DistributionPayment payment) {
  if (payment.paymentDate != null && payment.paymentDate!.isNotEmpty) {
    return PaymentDateInfo(
      label: formatPaymentDate(payment.paymentDate),
      isEstimated: false,
    );
  }
  return const PaymentDateInfo(label: '—', isEstimated: false);
}
