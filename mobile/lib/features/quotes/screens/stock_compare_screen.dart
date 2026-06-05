import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_compare_enhanced_view.dart';

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
          if (!_loading && _items.isNotEmpty)
            StockCompareEnhancedView(
              items: _items,
              market: CompareMarket.brazil,
            ),
        ],
      ),
    );
  }
}
