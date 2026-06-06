import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/core/utils/asset_magic_number.dart';
import 'package:rico_investidor/core/utils/parse_decimal.dart';
import 'package:rico_investidor/core/widgets/asset_magic_number_card.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/portfolio/widgets/add_asset_circle_card.dart';
import 'package:rico_investidor/features/portfolio/widgets/add_asset_suggestions.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
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
  final _averagePriceController = TextEditingController();
  AssetItem? _selected;
  UnifiedAssetSearchSnapshot _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();

  @override
  void initState() {
    super.initState();
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
    _averagePriceController.dispose();
    super.dispose();
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
      if (_averagePriceController.text.isEmpty && resolved.price > 0) {
        _averagePriceController.text = resolved.price.toStringAsFixed(2);
      }
    });
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

    widget.portfolio.addHolding(
      symbol: _selected!.symbol,
      name: _selected!.name,
      quantity: quantity,
      averagePrice: averagePrice,
      currentPrice: _selected!.price > 0 ? _selected!.price : null,
      changePercent: _selected!.price > 0 ? _selected!.changePercent : null,
      category: _selected!.category,
    );

    Navigator.pop(context, true);
  }

  void _openAssetProfile() {
    final asset = _selected;
    if (asset == null) return;

    openAssetDetail(
      context,
      asset: asset,
      fiiRepository: fiiRepository,
      quoteRepository: quoteRepository,
    );
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
            Text('Posição na carteira', style: Theme.of(context).textTheme.titleMedium),
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
              decoration: InputDecoration(
                labelText: (_selected?.category != null
                        ? holdingCurrencyForCategory(_selected!.category)
                        : HoldingCurrency.brl)
                    .averagePriceLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Os proventos serão estimados com base no histórico de pagamentos do ativo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvar na carteira'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openAssetProfile,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Ver perfil completo do ativo'),
            ),
          ],
        ],
      ),
    );
  }
}
