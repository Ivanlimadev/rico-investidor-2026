import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/simple_quote_line_chart.dart';
import 'package:rico_investidor/core/utils/quote_chart.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/models/market_series_models.dart';

class CryptoChartPreset {
  const CryptoChartPreset({required this.id, required this.label});

  final String id;
  final String label;
}

String _formatCryptoChartUsd(double value) {
  if (value >= 1000) return '\$${value.toStringAsFixed(0)}';
  return '\$${value.toStringAsFixed(2)}';
}

const cryptoChartPresets = [
  CryptoChartPreset(id: '1d', label: '1D'),
  CryptoChartPreset(id: '1w', label: '1S'),
  CryptoChartPreset(id: '1m', label: '1M'),
  CryptoChartPreset(id: '3m', label: '3M'),
  CryptoChartPreset(id: '1y', label: '1A'),
];

class CryptoChartCard extends StatefulWidget {
  const CryptoChartCard({
    super.key,
    required this.symbol,
    this.repository,
    this.initialCandles = const [],
    this.initialPreset = '1m',
    this.chartHeight = 220,
  });

  final String symbol;
  final CryptoRepository? repository;
  final List<CryptoCandleDto> initialCandles;
  final String initialPreset;
  final double chartHeight;

  @override
  State<CryptoChartCard> createState() => _CryptoChartCardState();
}

class _CryptoChartCardState extends State<CryptoChartCard> {
  static const _lineBlue = Color(0xFF3B82F6);

  late String _presetId;
  late Future<List<CryptoCandleDto>> _candlesFuture;
  int? _selectedIndex;

  CryptoRepository get _repository => widget.repository ?? cryptoRepository;

  @override
  void initState() {
    super.initState();
    _presetId = widget.initialPreset;
    _candlesFuture = _loadCandles();
  }

  Future<List<CryptoCandleDto>> _loadCandles() async {
    if (_presetId == widget.initialPreset && widget.initialCandles.isNotEmpty) {
      return widget.initialCandles;
    }
    final response = await _repository.getCandles(widget.symbol, preset: _presetId);
    return response.candles;
  }

  void _selectPreset(String presetId) {
    if (_presetId == presetId) return;
    setState(() {
      _presetId = presetId;
      _selectedIndex = null;
      _candlesFuture = _loadCandles();
    });
  }

  List<QuoteCandleBar> _toBars(List<CryptoCandleDto> candles) {
    final sorted = List<CryptoCandleDto>.from(candles)..sort((a, b) => a.date.compareTo(b.date));
    return sorted
        .map(
          (candle) => QuoteCandleBar(
            tradeDate: candle.date,
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close,
            volume: candle.volume,
          ),
        )
        .toList();
  }

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
            Text('Histórico', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: cryptoChartPresets.map((preset) {
                return FilterChip(
                  label: Text(preset.label),
                  selected: _presetId == preset.id,
                  onSelected: (_) => _selectPreset(preset.id),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<CryptoCandleDto>>(
              future: _candlesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: widget.chartHeight,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                final bars = _toBars(snapshot.data ?? const []);
                if (bars.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: Text('Histórico indisponível.')),
                  );
                }

                final selected = _selectedIndex != null && _selectedIndex! < bars.length
                    ? bars[_selectedIndex!]
                    : bars.last;
                final changePct = periodChangePct(bars);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'USD · ${bars.length} barras',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                          ),
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
                    const SizedBox(height: 10),
                    _SelectedBar(bar: selected),
                    const SizedBox(height: 8),
                    SimpleQuoteLineChart(
                      bars: bars,
                      height: widget.chartHeight,
                      lineColor: _lineBlue,
                      formatPrice: _formatCryptoChartUsd,
                      formatDateLabel: _formatDateLabel,
                      onSelectedIndex: (index) => setState(() => _selectedIndex = index),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateLabel(String raw) {
    if (raw.length >= 10) {
      final parts = raw.substring(0, 10).split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}';
    }
    return raw;
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.bar});

  final QuoteCandleBar bar;

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
          _formatCryptoChartUsd(bar.close),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B82F6),
              ),
        ),
      ],
    );
  }
}
