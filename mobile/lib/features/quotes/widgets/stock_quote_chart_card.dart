import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_quote_line_chart.dart';

class StockQuoteChartCard extends StatefulWidget {
  const StockQuoteChartCard({
    super.key,
    required this.ticker,
    required this.repository,
  });

  final String ticker;
  final QuoteRepository repository;

  @override
  State<StockQuoteChartCard> createState() => _StockQuoteChartCardState();
}

class _StockQuoteChartCardState extends State<StockQuoteChartCard> {
  FiiQuotePeriod _period = FiiQuotePeriod.year1;
  QuoteChartStyle _style = QuoteChartStyle.line;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Histórico de cotação', style: Theme.of(context).textTheme.titleSmall),
            Text(
              _style == QuoteChartStyle.candlestick
                  ? 'Candlestick · pregão B3'
                  : 'Gráfico de linha · pregão B3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            StockQuoteLineChart(
              ticker: widget.ticker,
              repository: widget.repository,
              chartHeight: 240,
              initialPeriod: _period,
              initialStyle: _style,
              onPeriodChanged: (period) => setState(() => _period = period),
              onStyleChanged: (style) => setState(() => _style = style),
            ),
          ],
        ),
      ),
    );
  }
}
