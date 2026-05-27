import 'package:rico_investidor/models/fii_models.dart';

const fiiDefaultPaymentType = 'Rendimento';

List<FiiDistributionPayment> sortPaymentsNewestFirst(List<FiiDistributionPayment> payments) {
  return List<FiiDistributionPayment>.from(payments)
    ..sort((a, b) => _paymentSortKey(b).compareTo(_paymentSortKey(a)));
}

FiiDistributionPayment? latestPayment(List<FiiDistributionPayment> payments) {
  final sorted = sortPaymentsNewestFirst(payments);
  return sorted.isEmpty ? null : sorted.first;
}

String paymentDisplayType(FiiDistributionPayment payment) {
  return fiiDefaultPaymentType;
}

String formatPaymentDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';

  final parts = raw.split('-');
  if (parts.length < 3) return raw;
  return '${parts[2].padLeft(2, '0')}/${parts[1]}/${parts[0]}';
}

String formatReferenceMonth(String? raw) {
  if (raw == null || raw.isEmpty) return '—';

  final parts = raw.split('-');
  if (parts.length < 2) return raw;

  const names = [
    '',
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return raw;
  return '${names[month]}/${parts[0]}';
}

/// Data COM aproximada: último dia útil do mês de referência.
String paymentComDate(FiiDistributionPayment payment) {
  final ref = _parseDate(payment.referenceDate);
  if (ref == null) return '—';

  final lastDay = DateTime(ref.year, ref.month + 1, 0);
  return formatPaymentDate(
    '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}',
  );
}

/// Quando a API não informa payment_date, estima ~14 do mês seguinte.
PaymentDateInfo paymentDateInfo(FiiDistributionPayment payment) {
  if (payment.paymentDate != null && payment.paymentDate!.isNotEmpty) {
    return PaymentDateInfo(
      label: formatPaymentDate(payment.paymentDate),
      isEstimated: false,
    );
  }

  final estimated = _estimatePaymentDate(payment.referenceDate);
  if (estimated == null) {
    return const PaymentDateInfo(label: '—', isEstimated: false);
  }

  return PaymentDateInfo(
    label: '~${formatPaymentDate(estimated)}',
    isEstimated: true,
  );
}

class PaymentDateInfo {
  const PaymentDateInfo({required this.label, required this.isEstimated});

  final String label;
  final bool isEstimated;
}

String? _estimatePaymentDate(String? referenceDate) {
  final ref = _parseDate(referenceDate);
  if (ref == null) return null;

  var month = ref.month + 1;
  var year = ref.year;
  if (month > 12) {
    month = 1;
    year += 1;
  }

  return '$year-${month.toString().padLeft(2, '0')}-14';
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String _paymentSortKey(FiiDistributionPayment payment) {
  return payment.referenceDate ?? payment.paymentDate ?? '';
}
