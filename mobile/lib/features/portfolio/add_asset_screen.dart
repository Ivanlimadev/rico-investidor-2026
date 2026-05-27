import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/parse_decimal.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key, required this.portfolio});

  final PortfolioState portfolio;

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _averagePriceController = TextEditingController();
  final _dividendAmountController = TextEditingController();
  DateTime? _dividendDate;
  AssetItem? _selected;
  List<AssetItem> _results = [];
  bool _includeDividend = false;
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _quantityController.dispose();
    _averagePriceController.dispose();
    _dividendAmountController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    final results = await widget.portfolio.searchService.searchAsync(value);

    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      if (_selected != null &&
          !value.toUpperCase().contains(_selected!.symbol) &&
          !value.toLowerCase().contains(_selected!.name.toLowerCase())) {
        _selected = null;
      }
    });
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
    setState(() {
      _selected = resolved;
      _searchController.text = '${resolved.symbol} — ${resolved.name}';
      _results = [];
      if (_averagePriceController.text.isEmpty && resolved.price > 0) {
        _averagePriceController.text = resolved.price.toStringAsFixed(2);
      }
    });
  }

  Future<void> _pickDividendDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dividendDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dividendDate = picked);
    }
  }

  void _save() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Busque e selecione um ativo')),
      );
      return;
    }

    final quantity = parseDecimalInput(_quantityController.text);
    final averagePrice = parseDecimalInput(_averagePriceController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida')),
      );
      return;
    }
    if (averagePrice == null || averagePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um preço médio válido')),
      );
      return;
    }

    DividendPayment? initialDividend;
    if (_includeDividend) {
      final amount = parseDecimalInput(_dividendAmountController.text);
      if (amount == null || amount <= 0 || _dividendDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha valor e data do dividendo')),
        );
        return;
      }
      initialDividend = DividendPayment(
        id: '',
        symbol: _selected!.symbol,
        name: _selected!.name,
        amount: amount,
        date: _dividendDate!,
      );
    }

    widget.portfolio.addHolding(
      symbol: _selected!.symbol,
      name: _selected!.name,
      quantity: quantity,
      averagePrice: averagePrice,
      currentPrice: _selected!.price > 0 ? _selected!.price : null,
      changePercent: _selected!.price > 0 ? _selected!.changePercent : null,
      initialDividend: initialDividend,
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar ativo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Buscar ativo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nome ou ticker (ex.: HGLG11, Petrobras)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
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
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _results.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: AssetListLeading(symbol: _results[i].symbol, logoUrl: _results[i].logoUrl),
                      title: Text(_results[i].symbol),
                      subtitle: Text(_results[i].name),
                      trailing: _results[i].price > 0
                          ? Text(
                              'R\$ ${_results[i].price.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : const Text('FII'),
                      onTap: () => _selectAsset(_results[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_selected != null) ...[
            const SizedBox(height: 24),
            Text('Posição', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _averagePriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preço médio (R\$)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Registrar dividendo recebido'),
              subtitle: const Text('Opcional — valor e data do provento'),
              value: _includeDividend,
              onChanged: (v) => setState(() => _includeDividend = v),
            ),
            if (_includeDividend) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _dividendAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Dividendos recebidos (R\$)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data do provento'),
                subtitle: Text(
                  _dividendDate == null
                      ? 'Toque para escolher'
                      : '${_dividendDate!.day.toString().padLeft(2, '0')}/'
                          '${_dividendDate!.month.toString().padLeft(2, '0')}/'
                          '${_dividendDate!.year}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDividendDate,
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: const Text('Salvar na carteira')),
          ],
        ],
      ),
    );
  }
}
