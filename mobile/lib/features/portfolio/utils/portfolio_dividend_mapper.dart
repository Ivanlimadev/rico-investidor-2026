import 'package:rico_investidor/core/utils/parse_market_date.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/market_series_models.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

List<DividendPayment> mapDistributionPaymentsToPortfolio({
  required PortfolioHolding holding,
  required Iterable<DistributionPayment> payments,
  required DateTime cutoff,
  String defaultKind = 'Provento',
  bool onlyCurrentMonth = false,
}) {
  final results = <DividendPayment>[];
  final now = DateTime.now();

  for (final payment in payments) {
    final paymentDay = parseMarketDate(payment.paymentDate);
    final comDay = parseMarketDate(payment.referenceDate);
    final anchor = paymentDay ?? comDay;
    final perShare = payment.valuePerShare;
    if (anchor == null || perShare == null || perShare <= 0) continue;

    final day = DateTime(anchor.year, anchor.month, anchor.day);
    if (day.isBefore(cutoff)) continue;
    if (onlyCurrentMonth && !_isSameMonth(day, now) && (comDay == null || !_isSameMonth(comDay, now))) {
      continue;
    }

    final total = perShare * holding.quantity;
    if (total <= 0) continue;

    final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

    results.add(
      DividendPayment(
        id: _syncId(holding.symbol, day, comDay),
        symbol: holding.symbol,
        name: holding.name,
        amount: total,
        date: day,
        kind: payment.label?.trim().isNotEmpty == true ? payment.label!.trim() : defaultKind,
        amountPerShare: perShare,
        comDate: comDay == null ? null : DateTime(comDay.year, comDay.month, comDay.day),
        quantity: holding.quantity,
        isProjected: isFuture,
      ),
    );
  }

  return results;
}

List<DividendPayment> mapUpcomingEventsToPortfolio({
  required PortfolioHolding holding,
  required Iterable<StockDividendEventDto> events,
  required DateTime month,
}) {
  final results = <DividendPayment>[];
  final seen = <String>{};

  for (final event in events) {
    final paymentDay = _parseDay(event.paymentDate);
    final comDay = _parseDay(event.comDate ?? event.exDate);
    final anchor = paymentDay ?? comDay;
    final perShare = event.valuePerShare;
    if (anchor == null || perShare == null || perShare <= 0) continue;
    if (!_isSameMonth(anchor, month) && (comDay == null || !_isSameMonth(comDay, month))) {
      continue;
    }

    final day = DateTime(anchor.year, anchor.month, anchor.day);
    final id = _syncId(holding.symbol, day, comDay);
    if (!seen.add(id)) continue;

    final total = perShare * holding.quantity;
    if (total <= 0) continue;

    results.add(
      DividendPayment(
        id: id,
        symbol: holding.symbol,
        name: holding.name,
        amount: total,
        date: day,
        kind: event.label?.trim().isNotEmpty == true ? event.label!.trim() : 'Provento',
        amountPerShare: perShare,
        comDate: comDay,
        quantity: holding.quantity,
        isProjected: event.isProjected || day.isAfter(DateTime.now()),
      ),
    );
  }

  return results;
}

DateTime? _parseDay(String? raw) {
  if (raw == null || raw.length < 10) return null;
  final parsed = DateTime.tryParse(raw.substring(0, 10));
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

String _syncId(String symbol, DateTime payment, DateTime? com) {
  final comPart = com == null ? '' : '-${com.toIso8601String().split('T').first}';
  return 'sync-${symbol.toUpperCase()}-${payment.toIso8601String().split('T').first}$comPart';
}

String monthNamePt(int month) {
  const labels = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return labels[month.clamp(1, 12) - 1];
}

String formatDividendDay(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String formatDividendDayOrDash(DateTime? date) {
  if (date == null) return '—';
  return formatDividendDay(date);
}

String quantityUnitLabel(String symbol) => 'ações';
