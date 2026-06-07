String formatPct(double value, {int decimals = 2, bool showSign = false}) {
  final fixed = value.toStringAsFixed(decimals);
  if (!showSign || value == 0) return '$fixed%';
  return value > 0 ? '+$fixed%' : '$fixed%';
}
