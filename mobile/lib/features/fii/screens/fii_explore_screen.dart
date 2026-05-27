import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_screener_presets.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class FiiExploreScreen extends StatefulWidget {
  const FiiExploreScreen({super.key, required this.repository});

  final FiiRepository repository;

  @override
  State<FiiExploreScreen> createState() => _FiiExploreScreenState();
}

class _FiiExploreScreenState extends State<FiiExploreScreen> {
  String _presetId = 'dy_high';
  List<FiiScreenerItem> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final preset = fiiScreenerPresets.firstWhere((p) => p.id == _presetId);
    try {
      final response = await widget.repository.screener(preset.params);
      if (!mounted) return;
      setState(() {
        _items = response.data;
        _total = response.total;
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
        title: const Text('Explorar FIIs'),
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
              itemCount: fiiScreenerPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = fiiScreenerPresets[index];
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
            child: Text('$_total FIIs · explorar mercado', style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_items.isEmpty) return const Center(child: Text('Nenhum FII neste filtro.'));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return FiiScreenerTile(
          item: item,
          onTap: () => openTickerDetailQuick(context, item.ticker),
        );
      },
    );
  }
}

class FiiScreenerTile extends StatelessWidget {
  const FiiScreenerTile({super.key, required this.item, required this.onTap});

  final FiiScreenerItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: AssetCardHeader(
                      symbol: item.ticker,
                      name: item.name,
                      logoSize: kAssetLogoSizeCompact,
                      trailing: item.closePrice != null
                          ? Text(
                              formatBrl(item.closePrice!),
                              style: Theme.of(context).textTheme.titleSmall,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (item.dividendYieldTtm != null)
                    _MetricChip(
                      label: 'DY 12m',
                      value: formatPct(item.dividendYieldTtm!),
                      color: AppColors.positive,
                    ),
                  if (item.pvp != null)
                    _MetricChip(label: 'P/VP', value: item.pvp!.toStringAsFixed(2)),
                  if (item.vacancyPct != null)
                    _MetricChip(label: 'Vacância', value: formatPct(item.vacancyPct!)),
                  if (item.fundType != null) _MetricChip(label: 'Tipo', value: item.fundType!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
    );
  }
}
