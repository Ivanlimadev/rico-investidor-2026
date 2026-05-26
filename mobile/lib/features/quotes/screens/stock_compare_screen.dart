import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';
import 'package:rico_investidor/features/quotes/utils/stock_screener_presets.dart';

class StockCompareScreen extends StatefulWidget {
  const StockCompareScreen({
    super.key,
    required this.repository,
    this.initialTickers = const [],
  });

  final QuoteRepository repository;
  final List<String> initialTickers;

  @override
  State<StockCompareScreen> createState() => _StockCompareScreenState();
}

class _StockCompareScreenState extends State<StockCompareScreen> {
  final _controller = TextEditingController();
  final List<String> _tickers = [];
  List<StockCompareItemDto> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tickers.addAll(widget.initialTickers.take(3).map((t) => t.toUpperCase()));
    if (_tickers.isNotEmpty) _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_tickers.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await widget.repository.compareStocks(_tickers);
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _addTicker() {
    final raw = _controller.text.trim().toUpperCase();
    if (raw.isEmpty || _tickers.length >= 3) return;
    if (_tickers.contains(raw)) return;
    setState(() => _tickers.add(raw));
    _controller.clear();
    _load();
  }

  void _remove(String ticker) {
    setState(() {
      _tickers.remove(ticker);
      _items.removeWhere((item) => item.quote.symbol == ticker);
    });
    if (_tickers.isNotEmpty) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar ações'),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Ticker (ex.: PETR4)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _addTicker(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _tickers.length >= 3 ? null : _addTicker,
                child: const Text('Add'),
              ),
            ],
          ),
          if (_tickers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _tickers
                  .map(
                    (ticker) => InputChip(
                      label: Text(ticker),
                      onDeleted: () => _remove(ticker),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          if (!_loading && _items.isNotEmpty) _StockCompareTable(items: _items),
        ],
      ),
    );
  }
}

class _StockCompareTable extends StatelessWidget {
  const _StockCompareTable({required this.items});

  final List<StockCompareItemDto> items;

  String? _pct(double? value) => value == null ? null : formatPct(value);

  String? _num(double? value) => value?.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final rows = <(String, List<String?>, {bool highlight})>[
      (
        'Cotação',
        items.map((item) => formatBrl(item.quote.price)).toList(),
        highlight: false,
      ),
      (
        'Variação',
        items.map((item) => '${item.quote.changePercent >= 0 ? '+' : ''}${item.quote.changePercent.toStringAsFixed(2)}%').toList(),
        highlight: false,
      ),
      (
        'DY 12m',
        items.map((item) => _pct(item.fundamentals.dividendYield12m)).toList(),
        highlight: true,
      ),
      (
        'P/L',
        items.map((item) => _num(item.fundamentals.priceEarnings)).toList(),
        highlight: false,
      ),
      (
        'P/VP',
        items.map((item) => _num(item.fundamentals.priceToBook)).toList(),
        highlight: false,
      ),
      (
        'ROE',
        items.map((item) => _pct(item.fundamentals.returnOnEquity)).toList(),
        highlight: false,
      ),
      (
        'Margem líq.',
        items.map((item) => _pct(item.fundamentals.profitMargin)).toList(),
        highlight: false,
      ),
      (
        'Cap. mercado',
        items.map((item) => item.marketStats.marketCap != null ? formatCompactBrl(item.marketStats.marketCap!) : null).toList(),
        highlight: false,
      ),
      (
        'Setor',
        items.map((item) => sectorLabel(item.profile.sector)).toList(),
        highlight: false,
      ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 40),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 108),
                  for (final item in items)
                    SizedBox(
                      width: 112,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.quote.symbol,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              item.quote.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 1),
              for (final row in rows) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(row.$1, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                    for (final value in row.$2)
                      SizedBox(
                        width: 112,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            value ?? '—',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: row.highlight && value != null ? AppColors.positive : null,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
