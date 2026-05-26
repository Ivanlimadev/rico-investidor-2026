import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/fii/widgets/fii_quote_line_chart.dart';

class FiiChartFullscreenScreen extends StatefulWidget {
  const FiiChartFullscreenScreen({
    super.key,
    required this.ticker,
    required this.repository,
    this.initialPeriod = FiiQuotePeriod.year1,
  });

  final String ticker;
  final FiiRepository repository;
  final FiiQuotePeriod initialPeriod;

  @override
  State<FiiChartFullscreenScreen> createState() => _FiiChartFullscreenScreenState();
}

class _FiiChartFullscreenScreenState extends State<FiiChartFullscreenScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ticker} · Cotação'),
        actions: const [ShellHomeButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              Expanded(
                child: FiiQuoteLineChart(
                  ticker: widget.ticker,
                  repository: widget.repository,
                  initialPeriod: widget.initialPeriod,
                  fillHeight: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
