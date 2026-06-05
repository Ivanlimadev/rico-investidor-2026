import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/features/currency/data/currency_repository.dart';
import 'package:rico_investidor/features/currency/models/currency_models.dart';
import 'package:rico_investidor/core/utils/asset_candle_mappers.dart';
import 'package:rico_investidor/core/widgets/what_if_investment_card.dart';
import 'package:rico_investidor/features/currency/widgets/currency_history_chart.dart';
import 'package:rico_investidor/models/asset_item.dart';

class CurrencyDetailScreen extends StatefulWidget {
  const CurrencyDetailScreen({
    super.key,
    required this.pair,
    this.repository,
  });

  final String pair;
  final CurrencyRepository? repository;

  @override
  State<CurrencyDetailScreen> createState() => _CurrencyDetailScreenState();
}

class _CurrencyDetailScreenState extends State<CurrencyDetailScreen> {
  late Future<CurrencyDetailDto> _loadFuture;
  CurrencyDetailDto? _extendedDetail;
  AssetItem? _actionAsset;

  CurrencyRepository get _repository => widget.repository ?? currencyRepository;

  @override
  void initState() {
    super.initState();
    _loadFuture = _repository.getDetail(widget.pair).then((detail) {
      if (mounted) setState(() => _actionAsset = detail.quote.toAssetItem());
      _loadExtendedHistory();
      return detail;
    });
  }

  Future<void> _loadExtendedHistory() async {
    try {
      final extended = await _repository.getDetail(widget.pair, historyLimit: 1260);
      if (!mounted) return;
      setState(() => _extendedDetail = extended);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeCurrencyPair(widget.pair);

    return Scaffold(
      appBar: AppBar(
        title: Text(normalized),
        actions: [
          const ShellHomeButton(),
          if (_actionAsset != null) ...AssetQuickActions.appBarActions(context, _actionAsset!),
        ],
      ),
      body: FutureBuilder<CurrencyDetailDto>(
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
          final change = quote.changePercent ?? 0;
          final isPositive = change >= 0;
          final changeColor = isPositive ? AppColors.positive : AppColors.negative;
          final mid = quote.midPrice;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AssetCardHeader(
                symbol: quote.pair,
                name: quote.name,
                trailing: mid != null
                    ? Text(
                        formatCurrencyRate(mid, quote.pair),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              if (quote.changePercent != null)
                Text(
                  '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}% no dia',
                  style: TextStyle(color: changeColor, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              if (quote.updatedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Atualizado em ${quote.updatedAt}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ],
              const SizedBox(height: 16),
              _QuoteStatsGrid(quote: quote),
              if (mid != null && mid > 0) ...[
                const SizedBox(height: 12),
                WhatIfInvestmentCard(
                  currentPrice: mid,
                  history: historyFromCurrency(history),
                  unitLabel: 'cotação',
                ),
              ],
              const SizedBox(height: 16),
              CurrencyHistoryChart(pair: quote.pair, history: history),
              const SizedBox(height: 12),
              Text(
                'Cotações PTAX via Brapi (${quote.fromCurrency} → ${quote.toCurrency}).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuoteStatsGrid extends StatelessWidget {
  const _QuoteStatsGrid({required this.quote});

  final CurrencyQuoteDto quote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cotação do dia', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Compra (bid)', value: quote.bidPrice, pair: quote.pair)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'Venda (ask)', value: quote.askPrice, pair: quote.pair)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Máxima', value: quote.high, pair: quote.pair)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'Mínima', value: quote.low, pair: quote.pair)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.pair,
  });

  final String label;
  final double? value;
  final String pair;

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
            value != null ? formatCurrencyRate(value!, pair) : '—',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
