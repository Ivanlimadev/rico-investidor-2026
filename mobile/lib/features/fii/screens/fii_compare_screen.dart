import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiCompareScreen extends StatefulWidget {
  const FiiCompareScreen({
    super.key,
    required this.repository,
    this.initialTickers = const [],
  });

  final FiiRepository repository;
  final List<String> initialTickers;

  @override
  State<FiiCompareScreen> createState() => _FiiCompareScreenState();
}

class _FiiCompareScreenState extends State<FiiCompareScreen> {
  final _controller = TextEditingController();
  final List<String> _tickers = [];
  List<FiiDetail> _details = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tickers.addAll(widget.initialTickers.take(3));
    if (_tickers.isNotEmpty) _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_tickers.isEmpty) return;
    setState(() => _loading = true);
    final results = <FiiDetail>[];
    for (final ticker in _tickers) {
      try {
        results.add(await widget.repository.getDetail(ticker));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _details = results;
      _loading = false;
    });
  }

  void _addTicker() {
    final raw = _controller.text.trim().toUpperCase();
    if (raw.isEmpty || _tickers.length >= 3) return;
    if (_tickers.contains(raw)) return;
    setState(() {
      _tickers.add(raw);
      _controller.clear();
    });
    _load();
  }

  void _remove(String ticker) {
    setState(() {
      _tickers.remove(ticker);
      _details.removeWhere((d) => d.ticker == ticker);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar FIIs'),
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
                    labelText: 'Ticker (ex.: HGLG11)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _addTicker(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _tickers.length >= 3 ? null : _addTicker, child: const Text('Add')),
            ],
          ),
          if (_tickers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _tickers
                  .map(
                    (t) => InputChip(
                      label: Text(t),
                      onDeleted: () => _remove(t),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _details.isNotEmpty) _CompareTable(details: _details),
        ],
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.details});

  final List<FiiDetail> details;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, List<String?>)>[
      ('Cotação', details.map((d) => d.closePrice != null ? formatBrl(d.closePrice!) : null).toList()),
      ('P/VP', details.map((d) => d.pvp?.toStringAsFixed(2)).toList()),
      ('DY 12m', details.map((d) => d.dividendYieldTtm != null ? formatPct(d.dividendYieldTtm!) : null).toList()),
      ('Vacância', details.map((d) => d.vacancyPct != null ? formatPct(d.vacancyPct!) : null).toList()),
      ('Patrimônio', details.map((d) => d.netAssetValue != null ? formatCompactBrl(d.netAssetValue!) : null).toList()),
      ('Cotistas', details.map((d) => d.totalShareholders != null ? formatShareholders(d.totalShareholders!) : null).toList()),
      ('Tipo', details.map((d) => d.fundType).toList()),
      ('Segmento', details.map((d) => d.segment).toList()),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              for (final d in details)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      d.ticker,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 1),
          for (final row in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(row.$1, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
                for (final value in row.$2)
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        value ?? '—',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: row.$1 == 'DY 12m' && value != null ? AppColors.positive : null,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
