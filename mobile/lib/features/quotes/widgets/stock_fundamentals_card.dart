import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_macro.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

const _dictionaryKeys = <String, String>{
  'DY 12m': 'yield',
  'P/VP': 'priceToBook',
  'EV': 'enterpriseValue',
  'VP/cota': 'bookValue',
};

class StockFundamentalsCard extends StatefulWidget {
  const StockFundamentalsCard({
    super.key,
    required this.fundamentals,
    required this.repository,
  });

  final StockFundamentalsDto fundamentals;
  final QuoteRepository repository;

  @override
  State<StockFundamentalsCard> createState() => _StockFundamentalsCardState();
}

class _StockFundamentalsCardState extends State<StockFundamentalsCard> {
  late final Future<Map<String, DictionaryFieldDto>> _dictionaryFuture;

  @override
  void initState() {
    super.initState();
    _dictionaryFuture = _loadDictionary();
  }

  Future<Map<String, DictionaryFieldDto>> _loadDictionary() async {
    try {
      final response = await widget.repository.getFundamentalsDictionary();
      return {for (final field in response.fields) field.key: field};
    } catch (_) {
      return const {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, DictionaryFieldDto>>(
      future: _dictionaryFuture,
      builder: (context, snapshot) {
        final dictionary = snapshot.data ?? const {};
        final sections = _buildSections(widget.fundamentals);
        if (sections.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Fundamentos', style: Theme.of(context).textTheme.titleSmall),
                for (final section in sections) ...[
                  const SizedBox(height: 14),
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final item in section.items)
                        _MetricTile(
                          label: item.label,
                          value: item.value!,
                          highlight: item.highlight,
                          dictionaryField: _dictionaryKeys[item.label] != null
                              ? dictionary[_dictionaryKeys[item.label]]
                              : null,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<_FundSection> _buildSections(StockFundamentalsDto fundamentals) {
    return <_FundSection>[
      _FundSection(
        title: 'Valuation',
        items: [
          _FundItem('DY 12m', _pct(fundamentals.dividendYield12m), highlight: true),
          _FundItem('P/L', _num(fundamentals.priceEarnings)),
          _FundItem('P/VP', _num(fundamentals.priceToBook)),
          _FundItem('P/L fwd.', _num(fundamentals.forwardPe)),
          _FundItem('EV', _compact(fundamentals.enterpriseValue)),
          _FundItem('EV/EBITDA', _num(fundamentals.enterpriseToEbitda)),
        ],
      ),
      _FundSection(
        title: 'Resultado',
        items: [
          _FundItem('Receita', _compact(fundamentals.totalRevenue)),
          _FundItem('EBITDA', _compact(fundamentals.ebitda)),
          _FundItem('FCF', _compact(fundamentals.freeCashflow)),
          _FundItem('LPA', _money(fundamentals.earningsPerShare)),
          _FundItem('VP/cota', _money(fundamentals.bookValuePerShare)),
        ],
      ),
      _FundSection(
        title: 'Rentabilidade',
        items: [
          _FundItem('ROE', _pct(fundamentals.returnOnEquity)),
          _FundItem('ROA', _pct(fundamentals.returnOnAssets)),
          _FundItem('Margem líq.', _pct(fundamentals.profitMargin)),
          _FundItem('Margem bruta', _pct(fundamentals.grossMargin)),
          _FundItem('Margem oper.', _pct(fundamentals.operatingMargin)),
        ],
      ),
      _FundSection(
        title: 'Crescimento',
        items: [
          _FundItem('Cresc. receita', _pct(fundamentals.revenueGrowth)),
          _FundItem('Cresc. lucro', _pct(fundamentals.earningsGrowth)),
        ],
      ),
      _FundSection(
        title: 'Endividamento',
        items: [
          _FundItem('Dív./PL', _num(fundamentals.debtToEquity)),
          _FundItem('Caixa', _compact(fundamentals.totalCash)),
          _FundItem('Dívida', _compact(fundamentals.totalDebt)),
          _FundItem('Liquidez corr.', _num(fundamentals.currentRatio)),
          _FundItem('Payout', _pct(fundamentals.payoutRatio)),
          _FundItem('Beta', _num(fundamentals.beta)),
        ],
      ),
      _FundSection(
        title: 'Analistas',
        items: [
          _FundItem('Recomendação', _recommendation(fundamentals.recommendationKey)),
          _FundItem('Preço-alvo', _money(fundamentals.targetMeanPrice)),
          _FundItem('Analistas', _count(fundamentals.numberOfAnalystOpinions)),
        ],
      ),
    ].map((section) {
      final visible = section.items.where((item) => item.value != null).toList();
      return _FundSection(title: section.title, items: visible);
    }).where((section) => section.items.isNotEmpty).toList();
  }

  String? _pct(double? value) {
    if (value == null) return null;
    return '${value.toStringAsFixed(2)}%';
  }

  String? _num(double? value) {
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  String? _money(double? value) {
    if (value == null) return null;
    return formatBrl(value);
  }

  String? _compact(double? value) {
    if (value == null) return null;
    return formatCompactBrl(value);
  }

  String? _count(int? value) {
    if (value == null) return null;
    return '$value';
  }

  String? _recommendation(String? key) {
    if (key == null || key.isEmpty) return null;
    return switch (key) {
      'strong_buy' => 'Compra forte',
      'buy' => 'Compra',
      'hold' => 'Neutro',
      'underperform' => 'Abaixo',
      'sell' => 'Venda',
      'strong_sell' => 'Venda forte',
      _ => key.replaceAll('_', ' '),
    };
  }
}

class _FundSection {
  const _FundSection({required this.title, required this.items});

  final String title;
  final List<_FundItem> items;
}

class _FundItem {
  const _FundItem(this.label, this.value, {this.highlight = false});

  final String label;
  final String? value;
  final bool highlight;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.dictionaryField,
  });

  final String label;
  final String value;
  final bool highlight;
  final DictionaryFieldDto? dictionaryField;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.positive : null;
    final hasTooltip = dictionaryField?.description?.isNotEmpty == true;

    final tile = Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.positive.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: highlight ? Border.all(color: AppColors.positive.withValues(alpha: 0.25)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ),
              if (hasTooltip)
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (!hasTooltip) return tile;

    return Tooltip(
      message: dictionaryField!.description!,
      preferBelow: false,
      child: tile,
    );
  }
}
