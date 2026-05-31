String formatBrl(double value) {
  final negative = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts[0];
  final decimals = parts[1];

  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    if (i > 0 && (integer.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(integer[i]);
  }

  final formatted = 'R\$ $buffer,$decimals';
  return negative ? '- $formatted' : formatted;
}

String formatCurrencyRate(double value, String pair) {
  final normalized = pair.trim().toUpperCase();
  final decimals = normalized.startsWith('JPY-') ? 5 : 4;
  final negative = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integer = parts[0];
  final fraction = parts[1];

  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    if (i > 0 && (integer.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(integer[i]);
  }

  final formatted = 'R\$ $buffer,$fraction';
  return negative ? '- $formatted' : formatted;
}

String formatCompactBrl(double value) {
  final abs = value.abs();
  final prefix = value < 0 ? '- ' : '';
  if (abs >= 1e12) return '${prefix}R\$ ${(abs / 1e12).toStringAsFixed(1)} tri';
  if (abs >= 1e9) return '${prefix}R\$ ${(abs / 1e9).toStringAsFixed(1)} bi';
  if (abs >= 1e6) return '${prefix}R\$ ${(abs / 1e6).toStringAsFixed(1)} mi';
  return formatBrl(value);
}

String formatUsd(double value) {
  final negative = value < 0;
  final abs = value.abs();
  final fixed = abs >= 1000 ? abs.toStringAsFixed(2) : abs.toStringAsFixed(2);
  final formatted = '\$$fixed';
  return negative ? '-$formatted' : formatted;
}

String formatCompactUsd(double value) {
  final abs = value.abs();
  final prefix = value < 0 ? '- ' : '';
  if (abs >= 1e12) return '${prefix}\$${(abs / 1e12).toStringAsFixed(1)}T';
  if (abs >= 1e9) return '${prefix}\$${(abs / 1e9).toStringAsFixed(1)}B';
  if (abs >= 1e6) return '${prefix}\$${(abs / 1e6).toStringAsFixed(1)}M';
  return formatUsd(value);
}
