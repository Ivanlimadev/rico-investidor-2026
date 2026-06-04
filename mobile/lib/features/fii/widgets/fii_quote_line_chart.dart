import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/simple_quote_line_chart.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiQuoteLineChart extends StatefulWidget {
  const FiiQuoteLineChart({
    super.key,
    required this.ticker,
    required this.repository,
    this.chartHeight = 240,
    this.fillHeight = false,
    this.initialPeriod = FiiQuotePeriod.year1,
    this.showPeriodSelector = true,
    this.onPeriodChanged,
    this.initialCandles = const [],
  });

  final String ticker;
  final FiiRepository repository;
  final double chartHeight;
  final bool fillHeight;
  final FiiQuotePeriod initialPeriod;
  final bool showPeriodSelector;
  final ValueChanged<FiiQuotePeriod>? onPeriodChanged;
  final List<FiiCandleBar> initialCandles;

  @override
  State<FiiQuoteLineChart> createState() => _FiiQuoteLineChartState();
}

class _FiiQuoteLineChartState extends State<FiiQuoteLineChart> {
  late FiiQuotePeriod _period = widget.initialPeriod;
  List<FiiCandleBar> _bars = const [];
  int? _selectedIndex;
  bool _loading = true;
  bool _loadingMore = false;
  bool _canLoadMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_seedFromInitialCandles(widget.initialPeriod)) {
      return;
    }
    _loadPeriod(reset: true);
  }

  bool _seedFromInitialCandles(FiiQuotePeriod period) {
    if (widget.initialCandles.isEmpty) return false;

    final needed = limitForQuotePeriod(period);
    if (widget.initialCandles.length < needed) return false;

    final sorted = sortedQuoteBars(widget.initialCandles);
    if (sorted.isEmpty) return false;

    _bars = sorted;
    _loading = false;
    _selectedIndex = sorted.length - 1;
    _canLoadMore = period == FiiQuotePeriod.max && _bars.length >= 2;
    return true;
  }

  Future<void> _loadPeriod({required bool reset}) async {
    if (reset && _seedFromInitialCandles(_period)) {
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _bars = const [];
        _canLoadMore = false;
        _selectedIndex = null;
      }
    });

    try {
      final response = await widget.repository.getCandles(
        widget.ticker,
        limit: limitForQuotePeriod(_period),
      );
      if (!mounted) return;

      final sorted = sortedQuoteBars(response.candles);
      setState(() {
        _bars = response.candles;
        _loading = false;
        _selectedIndex = sorted.isEmpty ? null : sorted.length - 1;
        _canLoadMore = _period == FiiQuotePeriod.max && _bars.length >= 2;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadOlderQuotes() async {
    if (!_canLoadMore || _loadingMore || _bars.length < 2) return;

    final end = dayBefore(sortedQuoteBars(_bars).first.tradeDate);
    if (end == null) return;

    setState(() => _loadingMore = true);
    try {
      final response = await widget.repository.getCandles(
        widget.ticker,
        limit: 500,
        end: end,
      );
      if (!mounted) return;

      setState(() {
        if (response.candles.isEmpty) {
          _canLoadMore = false;
        } else {
          _bars = [..._bars, ...response.candles];
          if (response.candles.length < 500) _canLoadMore = false;
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onPeriodSelected(FiiQuotePeriod period) {
    if (_period == period) return;
    setState(() => _period = period);
    widget.onPeriodChanged?.call(period);
    _loadPeriod(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = sortedQuoteBars(_bars);
    final changePct = periodChangePct(_bars);
    final selected = _selectedIndex != null && _selectedIndex! < sorted.length
        ? sorted[_selectedIndex!]
        : (sorted.isNotEmpty ? sorted.last : null);

    final chart = _buildChart(context, sorted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPeriodSelector) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: FiiQuotePeriod.values.map((period) {
              return FilterChip(
                label: Text(quotePeriodLabel(period)),
                selected: _period == period,
                onSelected: (_) => _onPeriodSelected(period),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(quotePeriodHint(_period), style: Theme.of(context).textTheme.bodySmall),
              ),
              if (changePct != null)
                Text(
                  '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: changePct >= 0 ? AppColors.positive : AppColors.negative,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (selected != null) _SelectedQuoteBar(bar: selected),
        const SizedBox(height: 8),
        if (widget.fillHeight) Expanded(child: chart) else SizedBox(height: widget.chartHeight, child: chart),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        if (_period == FiiQuotePeriod.max && _canLoadMore && !_loadingMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _loadOlderQuotes,
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Carregar histórico mais antigo'),
            ),
          ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, List<FiiCandleBar> sorted) {
    if (_loading) {
      return _frame(context, child: const Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return _frame(
        context,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Não foi possível carregar o gráfico.\n$_error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    if (sorted.length < 2) {
      return _frame(
        context,
        child: Center(
          child: Text(
            'Histórico insuficiente para o gráfico.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return _frame(
      context,
      child: SimpleQuoteLineChart(
        bars: sorted,
        height: widget.chartHeight,
        lineColor: SimpleQuoteLineChart.defaultLineColor,
        formatPrice: formatBrl,
        formatDateLabel: (raw) => _formatChartDateLabel(sorted, raw),
        onSelectedIndex: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  String _formatChartDateLabel(List<FiiCandleBar> sorted, String tradeDate) {
    final index = sorted.indexWhere((bar) => bar.tradeDate == tradeDate);
    if (index >= 0) {
      final label = axisLabelForIndex(sorted, index, _period);
      if (label.isNotEmpty) return label;
    }
    return formatQuoteDate(tradeDate);
  }

  Widget _frame(BuildContext context, {required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.65)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
          child: child,
        ),
      ),
    );
  }

}

class _SelectedQuoteBar extends StatelessWidget {
  const _SelectedQuoteBar({required this.bar});

  final FiiCandleBar bar;

  @override
  Widget build(BuildContext context) {
    final change = bar.open == 0 ? 0.0 : ((bar.close - bar.open) / bar.open) * 100;
    final positive = change >= 0;
    final color = positive ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatQuoteDate(bar.tradeDate),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text('Toque no gráfico para explorar', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatBrl(bar.close),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                '${positive ? '+' : ''}${change.toStringAsFixed(2)}% no dia',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
