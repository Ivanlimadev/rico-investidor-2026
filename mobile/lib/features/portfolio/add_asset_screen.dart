import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/core/utils/market_category_storage.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/core/utils/asset_magic_number.dart';
import 'package:rico_investidor/core/utils/parse_decimal.dart';
import 'package:rico_investidor/core/widgets/asset_magic_number_card.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/portfolio/data/portfolio_repository.dart';
import 'package:rico_investidor/features/portfolio/widgets/add_asset_circle_card.dart';
import 'package:rico_investidor/features/portfolio/widgets/add_asset_suggestions.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/services/recent_searched_assets_storage.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({
    super.key,
    required this.portfolio,
    this.initialAsset,
  });

  final PortfolioState portfolio;
  final AssetItem? initialAsset;

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _searchController = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _feesController = TextEditingController(text: '0');
  final _brokerController = TextEditingController();
  final _dateController = TextEditingController();
  AssetItem? _selected;
  String _transactionType = 'buy';
  DateTime _selectedDate = DateTime.now();
  UnifiedAssetSearchSnapshot _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
    _quantityController.addListener(_onFormChanged);
    _priceController.addListener(_onFormChanged);
    _feesController.addListener(_onFormChanged);
    final initial = widget.initialAsset;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectAsset(initial);
      });
    }
  }

  @override
  void dispose() {
    _unifiedSearch.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _feesController.dispose();
    _brokerController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  HoldingCurrency get _currency {
    if (_selected?.category != null) {
      return holdingCurrencyForCategory(_selected!.category);
    }
    return HoldingCurrency.usd;
  }

  String get _pricePerUnitLabel {
    return switch (_currency) {
      HoldingCurrency.usd => 'Price per unit (US\$)',
      HoldingCurrency.brl => 'Price per unit (R\$)',
    };
  }

  double? get _previewTotal {
    final quantity = parseDecimalInput(_quantityController.text);
    final price = parseDecimalInput(_priceController.text);
    final fees = parseDecimalInput(_feesController.text) ?? 0;
    if (quantity == null || price == null || quantity <= 0 || price <= 0) return null;
    return (quantity * price) + fees;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  void _onSearchChanged(String value) {
    _unifiedSearch.search(
      value,
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _searchSnapshot = snapshot;
          if (_selected != null &&
              !value.toUpperCase().contains(_selected!.symbol) &&
              !value.toLowerCase().contains(_selected!.name.toLowerCase())) {
            _selected = null;
          }
        });
      },
      preferredMarket: AppShellScope.maybeOf(context)?.preferredMarket,
    );
  }

  Future<void> _selectAsset(AssetItem asset) async {
    var resolved = asset;

    if (resolved.price <= 0) {
      final detailed = await widget.portfolio.searchService.findBySymbolAsync(asset.symbol);
      if (detailed != null && detailed.price > 0) {
        resolved = detailed;
      }
    }

    if (!mounted) return;
    unawaited(recentSearchedAssetsStorage.record(resolved));
    setState(() {
      _selected = resolved;
      _searchController.text = '${resolved.symbol} — ${resolved.name}';
      _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();
      if (_priceController.text.isEmpty && resolved.price > 0) {
        _priceController.text = resolved.price.toStringAsFixed(2);
      }
    });
  }

  Future<void> _save() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search and select an asset')),
      );
      return;
    }

    final quantity = parseDecimalInput(_quantityController.text);
    final pricePerUnit = parseDecimalInput(_priceController.text);
    final fees = parseDecimalInput(_feesController.text) ?? 0;
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }
    if (pricePerUnit == null || pricePerUnit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    final currency = _currency;
    final category = marketCategoryToStorage(_selected!.category);

    if (portfolioRepository.canSync) {
      try {
        var livePrice = _selected!.price;
        var liveChange = _selected!.changePercent;
        try {
          final quote = await globalMarketRepository.refreshQuote(_selected!.symbol);
          if (quote.price > 0) {
            livePrice = quote.price;
            liveChange = quote.changePercent;
          }
        } catch (_) {}

        final holdings = await portfolioRepository.addTransaction(
          symbol: _selected!.symbol,
          name: _selected!.name,
          transactionType: _transactionType,
          date: _selectedDate,
          quantity: quantity,
          pricePerUnit: pricePerUnit,
          fees: fees,
          broker: _brokerController.text.trim().isEmpty ? null : _brokerController.text.trim(),
          currency: currency.code,
          category: category,
        );

        widget.portfolio.holdings
          ..clear()
          ..addAll(holdings);

        if (livePrice > 0) {
          for (var i = 0; i < widget.portfolio.holdings.length; i++) {
            final holding = widget.portfolio.holdings[i];
            if (holding.symbol.toUpperCase() == _selected!.symbol.toUpperCase()) {
              widget.portfolio.holdings[i] = holding.copyWith(
                currentPrice: livePrice,
                changePercent: liveChange,
              );
              break;
            }
          }
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save transaction. Try again.')),
        );
        return;
      }
    } else {
      widget.portfolio.addHolding(
        symbol: _selected!.symbol,
        name: _selected!.name,
        quantity: quantity,
        averagePrice: pricePerUnit,
        currentPrice: _selected!.price > 0 ? _selected!.price : null,
        changePercent: _selected!.price > 0 ? _selected!.changePercent : null,
        category: _selected!.category,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _openAssetProfile() {
    final asset = _selected;
    if (asset == null) return;

    openAssetDetail(
      context,
      asset: asset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewTotal = _previewTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Add asset')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Search asset', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: kUnifiedAssetSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchSnapshot.loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
          if (!_searchSnapshot.active && _selected == null) ...[
            const SizedBox(height: 20),
            AddAssetSuggestions(onAssetTap: _selectAsset),
          ],
          if (_searchSnapshot.active && _searchSnapshot.results.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _searchSnapshot.results.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: AssetSearchLeading(asset: _searchSnapshot.results[i]),
                      title: Text(_searchSnapshot.results[i].symbol),
                      subtitle: Text(_searchSnapshot.results[i].name),
                      trailing: Chip(
                        label: Text(
                          _searchSnapshot.results[i].category.title,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onTap: () => _selectAsset(_searchSnapshot.results[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_selected != null) ...[
            const SizedBox(height: 24),
            Center(
              child: AddAssetCircleAssetCard(
                asset: _selected!,
                logoSize: 64,
                onTap: null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selected!.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            if (magicNumberFromAssetItem(_selected!) case final magic?) ...[
              const SizedBox(height: 12),
              AssetMagicNumberCompact(
                result: magic,
                unitPlural: magicNumberUnitPlural(_selected!.category),
                currency: holdingCurrencyForCategory(_selected!.category),
              ),
            ],
            const SizedBox(height: 20),
            Text('Position details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'buy', label: Text('Buy')),
                ButtonSegment(value: 'sell', label: Text('Sell')),
              ],
              selected: {_transactionType},
              onSelectionChanged: (value) {
                setState(() => _transactionType = value.first);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _pricePerUnitLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Fees / brokerage (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brokerController,
              decoration: const InputDecoration(
                labelText: 'Broker (optional, e.g. Fidelity, Schwab)',
                border: OutlineInputBorder(),
              ),
            ),
            if (previewTotal != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: ${_currency.format(previewTotal)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Dividends will be estimated based on the asset\'s payment history.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _save,
              child: const Text('Save transaction'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openAssetProfile,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('View full asset profile'),
            ),
          ],
        ],
      ),
    );
  }
}
