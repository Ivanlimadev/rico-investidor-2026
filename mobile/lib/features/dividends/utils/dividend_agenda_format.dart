import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/dividends/models/dividend_calendar_models.dart';

/// Data no estilo Investidor10 (dd/MM/yy).
String formatAgendaDate(String? isoDate) {
  if (isoDate == null || isoDate.length < 10) return '—';
  final parts = isoDate.split('-');
  if (parts.length < 3) return isoDate;
  final year = parts[0];
  final shortYear = year.length >= 2 ? year.substring(year.length - 2) : year;
  return '${parts[2].padLeft(2, '0')}/${parts[1]}/$shortYear';
}

String formatAgendaAmount(DividendCalendarEntry entry) {
  if (entry.currency == 'USD') {
    return 'US\$ ${entry.amount.toStringAsFixed(2)}';
  }
  return formatBrl(entry.amount);
}
