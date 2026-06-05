import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/features/indices/data/indices_repository.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';
import 'package:rico_investidor/core/utils/asset_candle_mappers.dart';
import 'package:rico_investidor/core/widgets/what_if_investment_card.dart';
import 'package:rico_investidor/features/indices/widgets/index_history_chart.dart';
import 'package:rico_investidor/models/asset_item.dart';

class IndexDetailScreen extends StatefulWidget {
  const IndexDetailScreen({
    super.key,
    required this.symbol,
    this.repository,
  });

  final String symbol;
  final IndicesRepository? repository;

  @override
  State<IndexDetailScreen> createState() => _IndexDetailScreenState();
}

class _IndexDetailScreenState extends State<IndexDetailScreen> {
  late Future<IndexDetailDto> _loadFuture;
  IndexDetailDto? _extendedDetail;
  AssetItem? _actionAsset;

  IndicesRepository get _repository => widget.repository ?? indicesRepository;

  @override
  void initState() {
    super.initState();
    _loadFuture = _repository.getDetail(widget.symbol).then((detail) {
      if (mounted) setState(() => _actionAsset = detail.quote.toAssetItem());
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
    final normalized = normalizeIndexSymbol(widget.symbol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Índice'),
        actions: [
          const ShellHomeButton(),
          if (_actionAsset != null) ...AssetQuickActions.appBarActions(context, _actionAsset!),
        ],
      ),
      body: FutureBuilder<IndexDetailDto>(
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
          final quote = detail.quote;
          final history = _extendedDetail?.history ?? detail.history;
          final isPositive = quote.changePercent >= 0;
          final changeColor = isPositive ? AppColors.positive : AppColors.negative;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AssetCardHeader(
                symbol: indexDisplaySymbol(quote.symbol),
                name: quote.name,
                trailing: Text(
                  formatIndexPoints(quote.price),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${isPositive ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}% no dia',
                style: TextStyle(color: changeColor, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(indexGroupLabel(quote.group))),
                  Chip(label: Text(quote.symbol)),
                ],
              ),
              const SizedBox(height: 16),
              _StatsGrid(quote: quote),
              if (quote.price > 0) ...[
                const SizedBox(height: 12),
                WhatIfInvestmentCard(
                  currentPrice: quote.price,
                  history: historyFromIndex(history),
                  unitLabel: 'ponto',
                ),
              ],
              const SizedBox(height: 16),
              IndexHistoryChart(history: history),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.quote});

  final IndexQuoteDto quote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Estatísticas do dia', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Máxima', value: quote.dayHigh)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'Mínima', value: quote.dayLow)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Fech. anterior', value: quote.previousClose)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: '52 sem.', value: quote.fiftyTwoWeekHigh)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, this.value});

  final String label;
  final double? value;

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
            value != null ? formatIndexPoints(value!) : '—',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
