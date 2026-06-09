const _monthNamesPt = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String financeMonthKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String financeMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return monthKey;
  return '${_monthNamesPt[month - 1]} $year';
}

DateTime financeMonthDate(String monthKey) {
  final parts = monthKey.split('-');
  final year = int.tryParse(parts[0]) ?? DateTime.now().year;
  final month = int.tryParse(parts[1]) ?? DateTime.now().month;
  return DateTime(year, month);
}

String shiftFinanceMonth(String monthKey, int deltaMonths) {
  final date = financeMonthDate(monthKey);
  final shifted = DateTime(date.year, date.month + deltaMonths);
  return financeMonthKey(shifted);
}

String get currentFinanceMonthKey => financeMonthKey(DateTime.now());

String financeDayHeader(DateTime date) {
  return '${date.day} de ${_monthNamesPt[date.month - 1]}';
}
