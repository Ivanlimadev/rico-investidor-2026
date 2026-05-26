import 'package:rico_investidor/features/fii/utils/fii_payments.dart';
import 'package:rico_investidor/models/fii_models.dart';

List<FiiDistributionPayment> sortStockPaymentsNewestFirst(List<FiiDistributionPayment> payments) {
  return sortPaymentsNewestFirst(payments);
}

String stockPaymentDisplayType(FiiDistributionPayment payment) {
  final label = payment.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  return 'Provento';
}

String stockPaymentComDate(FiiDistributionPayment payment) {
  return formatPaymentDate(payment.referenceDate);
}

PaymentDateInfo stockPaymentDateInfo(FiiDistributionPayment payment) {
  if (payment.paymentDate != null && payment.paymentDate!.isNotEmpty) {
    return PaymentDateInfo(
      label: formatPaymentDate(payment.paymentDate),
      isEstimated: false,
    );
  }
  return const PaymentDateInfo(label: '—', isEstimated: false);
}
