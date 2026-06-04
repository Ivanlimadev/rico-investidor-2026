import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_quote_line_chart.dart';
import 'package:rico_investidor/models/fii_models.dart';

class StockQuoteChartCard extends StatefulWidget {
  const StockQuoteChartCard({
    super.key,
    required this.ticker,
    required this.repository,
    this.initialCandles = const [],
  });

  final String ticker;
  final QuoteRepository repository;
  final List<FiiCandleBar> initialCandles;

  @override
  State<StockQuoteChartCard> createState() => _StockQuoteChartCardState();
}

bool _isBenchmarkTicker(String ticker) {
  final normalized = ticker.toUpperCase().trim();
  return normalized == 'BOVA11' || normalized == '^BVSP';
}

class _StockQuoteChartCardState extends State<StockQuoteChartCard> {
  FiiQuotePeriod _period = FiiQuotePeriod.year1;
  QuoteChartStyle _style = QuoteChartStyle.line;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Histórico de cotação', style: Theme.of(context).textTheme.titleSmall),
            Text(
              _style == QuoteChartStyle.candlestick
                  ? 'Candlestick · pregão B3'
                  : 'Fechamento diário · B3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            StockQuoteLineChart(
              ticker: widget.ticker,
              repository: widget.repository,
              chartHeight: 220,
              initialPeriod: _period,
              initialStyle: _style,
              initialCandles: widget.initialCandles,
              showBenchmarkCompare: !_isBenchmarkTicker(widget.ticker),
              onPeriodChanged: (period) => setState(() => _period = period),
              onStyleChanged: (style) => setState(() => _style = style),
            ),
          ],
        ),
      ),
    );
  }
}
