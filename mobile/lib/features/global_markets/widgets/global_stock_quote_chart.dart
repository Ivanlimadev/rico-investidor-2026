import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/simple_quote_line_chart.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/fii_models.dart';

enum GlobalStockChartPeriod { months3, months6, year1 }

class GlobalStockQuoteChart extends StatefulWidget {
  const GlobalStockQuoteChart({
    super.key,
    required this.candles,
    this.chartHeight = 220,
  });

  final List<GlobalStockCandleDto> candles;
  final double chartHeight;

  @override
  State<GlobalStockQuoteChart> createState() => _GlobalStockQuoteChartState();
}

class _GlobalStockQuoteChartState extends State<GlobalStockQuoteChart> {
  static const _lineBlue = Color(0xFF3B82F6);

  GlobalStockChartPeriod _period = GlobalStockChartPeriod.year1;
  int? _selectedIndex;
  bool _useAdjusted = false;

  bool get _hasAdjustedData => widget.candles.any(
        (c) => c.adjClose != null && (c.adjClose! - c.close).abs() > 0.0001,
      );

  @override
  void didUpdateWidget(covariant GlobalStockQuoteChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles.length != widget.candles.length) {
      _selectedIndex = null;
    }
    if (_useAdjusted && !_hasAdjustedData) {
      _useAdjusted = false;
    }
  }

  List<FiiCandleBar> get _allBars => dedupeQuoteBarsByDate(_toBars(widget.candles));

  List<FiiCandleBar> get _bars {
    final all = _allBars;
    return barsForTrailingTradingDays(all, maxBars: _tradingDaysFor(_period));
  }

  static int _tradingDaysFor(GlobalStockChartPeriod period) {
    return switch (period) {
      GlobalStockChartPeriod.months3 => 66,
      GlobalStockChartPeriod.months6 => 132,
      GlobalStockChartPeriod.year1 => 252,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    final selected = _selectedIndex != null && _selectedIndex! < bars.length
        ? bars[_selectedIndex!]
        : (bars.isNotEmpty ? bars.last : null);
    final changePct = periodChangePct(bars);

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
            Row(
              children: [
                Text('Histórico', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_hasAdjustedData)
                  FilterChip(
                    label: const Text('Ajustado'),
                    selected: _useAdjusted,
                    onSelected: (selected) => setState(() {
                      _useAdjusted = selected;
                      _selectedIndex = null;
                    }),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
                ...GlobalStockChartPeriod.values.map((period) {
                  return FilterChip(
                    label: Text(_periodLabel(period)),
                    selected: _period == period,
                    onSelected: (_) => setState(() {
                      _period = period;
                      _selectedIndex = null;
                    }),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  );
                }),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              _SelectedBar(bar: selected),
            ],
            const SizedBox(height: 8),
            SimpleQuoteLineChart(
              bars: bars,
              height: widget.chartHeight,
              lineColor: _lineBlue,
              formatPrice: _formatUsd,
              formatDateLabel: _formatDateLabel,
              onSelectedIndex: (index) => setState(() => _selectedIndex = index),
            ),
          ],
        ),
      ),
    );
  }

  List<FiiCandleBar> _toBars(List<GlobalStockCandleDto> candles) {
    final useAdjusted = _useAdjusted && _hasAdjustedData;
    return candles
        .map(
          (c) {
            final price = useAdjusted ? (c.adjClose ?? c.close) : c.close;
            if (price <= 0) return null;
            return FiiCandleBar(
              tradeDate: c.date,
              open: c.open ?? price,
              high: c.high ?? price,
              low: c.low ?? price,
              close: price,
              volume: c.volume,
            );
          },
        )
        .whereType<FiiCandleBar>()
        .toList();
  }

  static String _periodLabel(GlobalStockChartPeriod period) {
    return switch (period) {
      GlobalStockChartPeriod.months3 => '3M',
      GlobalStockChartPeriod.months6 => '6M',
      GlobalStockChartPeriod.year1 => '1A',
    };
  }

  static String _formatDateLabel(String raw) {
    if (raw.length >= 10) {
      final parts = raw.substring(0, 10).split('-');
      if (parts.length == 3) {
        const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
        final date = DateTime.tryParse(raw.substring(0, 10));
        if (date != null) {
          return '${weekdays[date.weekday - 1]} ${parts[2]}';
        }
      }
      return raw.substring(5, 10).replaceAll('-', '/');
    }
    return raw;
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.bar});

  final FiiCandleBar bar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          bar.tradeDate.length >= 10 ? bar.tradeDate.substring(0, 10) : bar.tradeDate,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatUsd(bar.close),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B82F6),
              ),
        ),
        if (bar.volume != null) ...[
          const Spacer(),
          Text(
            'Vol. ${_compactVolume(bar.volume!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  static String _compactVolume(double volume) {
    if (volume >= 1e9) return '${(volume / 1e9).toStringAsFixed(1)}B';
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(1)}M';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(1)}K';
    return volume.toStringAsFixed(0);
  }
}

String _formatUsd(double value) {
  if (value >= 1000) return '\$${value.toStringAsFixed(0)}';
  return '\$${value.toStringAsFixed(2)}';
}
