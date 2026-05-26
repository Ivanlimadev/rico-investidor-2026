import 'package:rico_investidor/core/utils/currency_format.dart';

class FinancialLineDto {
  const FinancialLineDto({
    required this.key,
    required this.label,
    this.value,
  });

  final String key;
  final String label;
  final double? value;

  factory FinancialLineDto.fromJson(Map<String, dynamic> json) {
    final value = json['value'];
    return FinancialLineDto(
      key: json['key'] as String,
      label: json['label'] as String,
      value: value == null ? null : (value as num).toDouble(),
    );
  }
}

class FinancialPeriodDto {
  const FinancialPeriodDto({
    required this.endDate,
    required this.lines,
  });

  final String endDate;
  final List<FinancialLineDto> lines;

  factory FinancialPeriodDto.fromJson(Map<String, dynamic> json) {
    final raw = json['lines'] as List<dynamic>? ?? const [];
    return FinancialPeriodDto(
      endDate: json['end_date'] as String,
      lines: raw.map((item) => FinancialLineDto.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class StockFinancialsDto {
  const StockFinancialsDto({
    required this.incomeStatement,
    required this.balanceSheet,
    required this.cashFlow,
    this.provider = 'brapi',
  });

  final List<FinancialPeriodDto> incomeStatement;
  final List<FinancialPeriodDto> balanceSheet;
  final List<FinancialPeriodDto> cashFlow;
  final String provider;

  bool get isEmpty =>
      incomeStatement.isEmpty && balanceSheet.isEmpty && cashFlow.isEmpty;

  factory StockFinancialsDto.fromJson(Map<String, dynamic> json) {
    List<FinancialPeriodDto> parseList(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw.map((item) => FinancialPeriodDto.fromJson(item as Map<String, dynamic>)).toList();
    }

    return StockFinancialsDto(
      incomeStatement: parseList('income_statement'),
      balanceSheet: parseList('balance_sheet'),
      cashFlow: parseList('cash_flow'),
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}

String formatFinancialPeriod(String endDate) {
  final date = DateTime.tryParse(endDate);
  if (date == null) return endDate;
  final quarter = ((date.month - 1) ~/ 3) + 1;
  final year = date.year.toString().substring(2);
  return '${quarter}T$year';
}

String formatFinancialValue(double? value) {
  if (value == null) return '—';
  return formatCompactBrl(value);
}
