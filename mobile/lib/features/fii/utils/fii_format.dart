export 'package:rico_investidor/core/utils/currency_format.dart' show formatBrl, formatCompactBrl;

String formatAreaSqm(double value) {
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)} mi m²';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(0)} mil m²';
  return '${value.toStringAsFixed(0)} m²';
}

String formatPct(double value, {int decimals = 2}) {
  return '${value.toStringAsFixed(decimals)}%';
}

String formatShareholders(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return '$value';
}

String formatSharesOutstanding(double value) {
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M cotas';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(0)}k cotas';
  return '${value.toStringAsFixed(0)} cotas';
}
