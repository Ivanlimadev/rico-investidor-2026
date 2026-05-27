import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/fii/utils/fii_data_freshness.dart';
import 'package:rico_investidor/models/fii_models.dart';

void main() {
  group('fii_data_freshness', () {
    test('latestQuoteTradeDate retorna o pregão mais recente', () {
      final date = latestQuoteTradeDate([
        FiiCandleBar(tradeDate: '2026-05-20', open: 1, high: 1, low: 1, close: 10),
        FiiCandleBar(tradeDate: '2026-05-23', open: 1, high: 1, low: 1, close: 11),
        FiiCandleBar(tradeDate: '2026-05-22', open: 1, high: 1, low: 1, close: 0),
      ]);

      expect(date, '2026-05-23');
    });

    test('cvmReportReferenceLabel formata mês do relatório', () {
      expect(
        cvmReportReferenceLabel('2026-04-01'),
        'Referência do relatório (CVM): Abr/2026',
      );
    });

    test('quoteUpdatedLabel formata data do pregão', () {
      expect(
        quoteUpdatedLabel('2026-05-23'),
        'Cotação atualizada em 23/05/2026 (último pregão)',
      );
    });
  });
}
