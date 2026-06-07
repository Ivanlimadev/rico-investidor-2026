import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/core/utils/quote_chart.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_candlestick_chart.dart';
import 'package:rico_investidor/models/market_series_models.dart';

class CryptoChartPreset {
  const CryptoChartPreset({required this.id, required this.label});

  final String id;
  final String label;
}

/// Presets do gráfico cripto (Binance). Sem MAX — histórico longo em 1d/1000
/// não batia com gráficos reais; 1A cobre o uso típico.
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
  });

  final String symbol;
  final CryptoRepository? repository;
  final List<CryptoCandleDto> initialCandles;
  final String initialPreset;

  @override
  State<CryptoChartCard> createState() => _CryptoChartCardState();
}

class _CryptoChartCardState extends State<CryptoChartCard> {
  late String _presetId;
  late Future<List<CryptoCandleDto>> _candlesFuture;
  bool _candlestick = true;
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

  List<QuoteCandleBar> _toFiiBars(List<CryptoCandleDto> candles) {
    return candles
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Gráfico (USD)', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Linha')),
                    ButtonSegment(value: true, label: Text('Candle')),
                  ],
                  selected: {_candlestick},
                  onSelectionChanged: (selection) => setState(() => _candlestick = selection.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cryptoChartPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final preset = cryptoChartPresets[index];
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: _presetId == preset.id,
                    onSelected: (_) => _selectPreset(preset.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<CryptoCandleDto>>(
              future: _candlesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                }
                final candles = snapshot.data ?? const [];
                if (candles.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: Text('Histórico indisponível.')),
                  );
                }

                final sorted = List<CryptoCandleDto>.from(candles)..sort((a, b) => a.date.compareTo(b.date));
                final selected = _selectedIndex != null && _selectedIndex! < sorted.length
                    ? sorted[_selectedIndex!]
                    : sorted.last;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selected.date, style: Theme.of(context).textTheme.labelLarge),
                                if (_candlestick) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'O ${formatCryptoPrice(selected.open)} · H ${formatCryptoPrice(selected.high)} · L ${formatCryptoPrice(selected.low)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            formatCryptoPrice(selected.close),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: _candlestick
                          ? StockCandlestickChart(
                              bars: _toFiiBars(sorted),
                              period: QuotePeriod.month1,
                              selectedIndex: _selectedIndex,
                              onSelected: (index) => setState(() => _selectedIndex = index),
                            )
                          : _LineChart(
                              candles: sorted,
                              selectedIndex: _selectedIndex,
                              onSelected: (index) => setState(() => _selectedIndex = index),
                            ),
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
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.candles,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CryptoCandleDto> candles;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < candles.length; i++) FlSpot(i.toDouble(), candles[i].close),
    ];
    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.08;
    final chartMinY = minY - padding;
    final chartMaxY = maxY + padding;

    return LineChart(
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (chartMaxY - chartMinY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.lineBarSpots == null ||
                response.lineBarSpots!.isEmpty) {
              return;
            }
            onSelected(response.lineBarSpots!.first.x.toInt());
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.positive,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.positive.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
