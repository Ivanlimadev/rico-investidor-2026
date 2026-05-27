import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_chart_fullscreen_screen.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/fii/widgets/fii_quote_line_chart.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiQuoteChartCard extends StatefulWidget {
  const FiiQuoteChartCard({
    super.key,
    required this.ticker,
    required this.repository,
    this.initialCandles = const [],
  });

  final String ticker;
  final FiiRepository repository;
  final List<FiiCandleBar> initialCandles;

  @override
  State<FiiQuoteChartCard> createState() => _FiiQuoteChartCardState();
}

class _FiiQuoteChartCardState extends State<FiiQuoteChartCard> {
  FiiQuotePeriod _period = FiiQuotePeriod.year1;

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FiiChartFullscreenScreen(
          ticker: widget.ticker,
          repository: widget.repository,
          initialPeriod: _period,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cotação', style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        'Gráfico de linha · pregão B3',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Expandir gráfico',
                  onPressed: _openFullscreen,
                  icon: const Icon(Icons.fullscreen),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FiiQuoteLineChart(
              ticker: widget.ticker,
              repository: widget.repository,
              chartHeight: 240,
              initialPeriod: _period,
              initialCandles: widget.initialCandles,
              onPeriodChanged: (period) => setState(() => _period = period),
            ),
          ],
        ),
      ),
    );
  }
}
