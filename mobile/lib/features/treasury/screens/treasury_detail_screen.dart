import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/features/treasury/data/treasury_repository.dart';
import 'package:rico_investidor/features/treasury/models/treasury_models.dart';
import 'package:rico_investidor/features/treasury/widgets/treasury_history_chart.dart';
import 'package:rico_investidor/models/asset_item.dart';

class TreasuryDetailScreen extends StatefulWidget {
  const TreasuryDetailScreen({
    super.key,
    required this.symbol,
    this.repository,
  });

  final String symbol;
  final TreasuryRepository? repository;

  @override
  State<TreasuryDetailScreen> createState() => _TreasuryDetailScreenState();
}

class _TreasuryDetailScreenState extends State<TreasuryDetailScreen> {
  late Future<TreasuryDetailDto> _loadFuture;
  TreasuryDetailDto? _extendedDetail;
  AssetItem? _actionAsset;

  TreasuryRepository get _repository => widget.repository ?? treasuryRepository;

  @override
  void initState() {
    super.initState();
    _loadFuture = _repository.getDetail(widget.symbol).then((detail) {
      if (mounted) setState(() => _actionAsset = detail.bond.toAssetItem());
      _loadExtendedHistory();
      return detail;
    });
  }

  Future<void> _loadExtendedHistory() async {
    try {
      final extended = await _repository.getDetail(widget.symbol, historyLimit: 1260);
      if (!mounted) return;
      setState(() => _extendedDetail = extended);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeTreasurySymbol(widget.symbol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tesouro Direto'),
        actions: [
          const ShellHomeButton(),
          if (_actionAsset != null) ...AssetQuickActions.appBarActions(context, _actionAsset!),
        ],
      ),
      body: FutureBuilder<TreasuryDetailDto>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar $normalized.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final bond = detail.bond;
          final history = _extendedDetail?.history ?? detail.history;
          final rateUnit = bond.rateInfo?.rateUnit ?? '% a.a.';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AssetCardHeader(
                symbol: bond.bondType,
                name: normalized,
                trailing: bond.displayPrice != null
                    ? Text(
                        formatBrl(bond.displayPrice!),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(label: 'Indexador', value: treasuryIndexerLabel(bond.indexer)),
                  _InfoChip(label: 'Cupom', value: treasuryCouponLabel(bond.couponType)),
                  if (bond.maturityDate != null)
                    _InfoChip(label: 'Vencimento', value: bond.maturityDate!),
                  if (bond.durationDays != null)
                    _InfoChip(label: 'Duration', value: '${bond.durationDays} dias'),
                ],
              ),
              if (bond.baseDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Atualizado em ${bond.baseDate}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ],
              const SizedBox(height: 16),
              _QuoteStatsGrid(bond: bond, rateUnit: rateUnit),
              const SizedBox(height: 16),
              TreasuryHistoryChart(history: history),
              if (bond.rateInfo?.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  bond.rateInfo!.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _QuoteStatsGrid extends StatelessWidget {
  const _QuoteStatsGrid({required this.bond, required this.rateUnit});

  final TreasuryBondDto bond;
  final String rateUnit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Taxas e preços indicativos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Taxa compra', value: formatTreasuryRate(bond.buyRate, unit: rateUnit))),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'Taxa venda', value: formatTreasuryRate(bond.sellRate, unit: rateUnit))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'PU compra', value: bond.buyPrice != null ? formatBrl(bond.buyPrice!) : '—')),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'PU venda', value: bond.sellPrice != null ? formatBrl(bond.sellPrice!) : '—')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
