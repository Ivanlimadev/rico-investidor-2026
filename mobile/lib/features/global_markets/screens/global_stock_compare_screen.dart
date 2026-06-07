import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/quote_refresh_timer.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_compare_enhanced_view.dart';

class GlobalStockCompareScreen extends StatefulWidget {
  const GlobalStockCompareScreen({
    super.key,
    required this.repository,
    this.initialTickers = const [],
  });

  final GlobalMarketRepository repository;
  final List<String> initialTickers;

  @override
  State<GlobalStockCompareScreen> createState() => _GlobalStockCompareScreenState();
}

class _GlobalStockCompareScreenState extends State<GlobalStockCompareScreen> {
  final _controller = TextEditingController();
  final List<String> _tickers = [];
  List<StockCompareItemDto> _items = [];
  bool _loading = false;
  String? _error;
  QuoteRefreshTimer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tickers.addAll(widget.initialTickers.take(3).map((t) => t.toUpperCase()));
    if (_tickers.isNotEmpty) _load();
    _configureAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _configureAutoRefresh() async {
    try {
      final caps = await widget.repository.getCapabilities();
      if (!caps.realtimeEnabled) return;
      _refreshTimer = QuoteRefreshTimer(onTick: () => _load(silent: true))..start(
            refreshSeconds: caps.refreshSeconds ?? 60,
            enabled: true,
          );
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (_tickers.isEmpty) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await widget.repository.compareStocks(_tickers);
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
        title: const Text('Comparar ações americanas'),
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
                    labelText: 'Ticker (ex.: AAPL)',
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
              market: CompareMarket.us,
            ),
        ],
      ),
    );
  }
}
