import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_screener.dart';
import 'package:rico_investidor/features/quotes/utils/stock_screener_presets.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class StockExploreScreen extends StatefulWidget {
  const StockExploreScreen({
    super.key,
    required this.repository,
    required this.fiiRepository,
    required this.category,
  });

  final QuoteRepository repository;
  final FiiRepository fiiRepository;
  final MarketCategory category;

  @override
  State<StockExploreScreen> createState() => _StockExploreScreenState();
}

class _StockExploreScreenState extends State<StockExploreScreen> {
  late String _presetId;
  late List<StockScreenerPreset> _presets;
  List<StockScreenerItemDto> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _presets = presetsForCategory(_categorySlug);
    _presetId = _presets.first.id;
    _load();
  }

  String get _categorySlug {
    return switch (widget.category) {
      MarketCategory.bdr => 'bdr',
      MarketCategory.etf => 'etf',
      _ => 'acoes_br',
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final preset = _presets.firstWhere((p) => p.id == _presetId);
    try {
      final response = await widget.repository.screener(preset.toQuery());
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _total = response.total ?? response.count;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explorar ${widget.category.title}'),
        actions: const [ShellHomeButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _presets.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = _presets[index];
                return FilterChip(
                  label: Text(preset.label),
                  selected: _presetId == preset.id,
                  onSelected: (_) {
                    setState(() => _presetId = preset.id);
                    _load();
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '$_total ativos · Brapi',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) return const Center(child: Text('Nenhum ativo neste filtro.'));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return StockScreenerTile(
          item: item,
          onTap: () => openAssetDetail(
            context,
            asset: item.toAssetItem(),
            fiiRepository: widget.fiiRepository,
            quoteRepository: widget.repository,
          ),
        );
      },
    );
  }
}

class StockScreenerTile extends StatelessWidget {
  const StockScreenerTile({super.key, required this.item, required this.onTap});

  final StockScreenerItemDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final changeColor = item.isPositive ? AppColors.positive : AppColors.negative;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item.logoUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.symbol, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatBrl(item.price), style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        '${item.isPositive ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (item.sector != null)
                    _MetricChip(label: 'Setor', value: sectorLabel(item.sector)),
                  if (item.marketCap != null)
                    _MetricChip(label: 'Cap.', value: formatCompactBrl(item.marketCap!)),
                  if (item.volume != null)
                    _MetricChip(label: 'Vol.', value: _formatVolume(item.volume!)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(1)} mi';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(0)} mil';
    return volume.toStringAsFixed(0);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
