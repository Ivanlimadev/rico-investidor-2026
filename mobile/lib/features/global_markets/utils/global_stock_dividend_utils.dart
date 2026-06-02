import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

const _frequencyLabels = {
  'm': 'Mensal',
  'q': 'Trimestral',
  's': 'Semestral',
  'sa': 'Semestral',
  'a': 'Anual',
  'y': 'Anual',
};

String formatGlobalDividendDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';

  final parts = raw.split('-');
  if (parts.length < 3) return raw;
  return '${parts[2].padLeft(2, '0')}/${parts[1]}/${parts[0]}';
}

String globalDividendFrequencyLabel(String? raw, {String? fallback}) {
  if (raw != null && raw.isNotEmpty) {
    return _frequencyLabels[raw.toLowerCase()] ?? raw;
  }
  return fallback ?? '—';
}

List<GlobalStockDividendDto> sortGlobalDividendsNewestFirst(List<GlobalStockDividendDto> dividends) {
  return List<GlobalStockDividendDto>.from(dividends)
    ..sort((a, b) => _dividendSortKey(b).compareTo(_dividendSortKey(a)));
}

String _dividendSortKey(GlobalStockDividendDto dividend) {
  return dividend.paymentDate ?? dividend.effectiveRecordDate ?? dividend.effectiveExDate;
}

String globalDividendTypeLabel(GlobalStockDividendDto dividend) {
  final label = dividend.dividendType.trim();
  if (label.isNotEmpty && label.toLowerCase() != 'dividendo') return label;
  return 'Dividendos';
}

/// Formato Investidor10: 8 casas decimais, vírgula como separador.
String formatGlobalDividendAmount(double value) {
  return value.toStringAsFixed(8).replaceAll('.', ',');
}
