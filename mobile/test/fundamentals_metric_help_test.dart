import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/quotes/models/stock_macro.dart';
import 'package:rico_investidor/features/quotes/utils/fundamentals_metric_help.dart';

void main() {
  test('resolveFundamentalsMetricHelp uses API and keeps local interpretation', () {
    final help = resolveFundamentalsMetricHelp('ROE', {
      'returnOnEquity': const DictionaryFieldDto(
        key: 'returnOnEquity',
        label: 'ROE',
        description: 'Retorno sobre patrimônio líquido.',
        calculation: 'ROE = lucro / PL',
      ),
    });

    expect(help, isNotNull);
    expect(help!.title, 'ROE');
    expect(help.description, contains('patrimônio'));
    expect(help.calculation, contains('ROE'));
    expect(help.interpretation, isNotEmpty);
  });

  test('resolveFundamentalsMetricHelp falls back to local glossary', () {
    final help = resolveFundamentalsMetricHelp('P/L', const {});

    expect(help, isNotNull);
    expect(help!.title, contains('P/L'));
    expect(help.description, isNotEmpty);
  });
}
