import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/features/dividends/data/dividend_calendar_repository.dart';
import 'package:rico_investidor/features/dividends/models/dividend_calendar_models.dart';
import 'package:rico_investidor/features/dividends/utils/dividend_agenda_format.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

void openDividendAgendaScreen(
  BuildContext context, {
  GlobalMarketRepository? globalMarketRepository,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DividendAgendaScreen(
        globalMarketRepository: globalMarketRepository,
      ),
    ),
  );
}

class DividendAgendaScreen extends StatefulWidget {
  const DividendAgendaScreen({
    super.key,
    this.globalMarketRepository,
  });

  final GlobalMarketRepository? globalMarketRepository;


  @override
  State<DividendAgendaScreen> createState() => _DividendAgendaScreenState();
}

class _DividendAgendaScreenState extends State<DividendAgendaScreen> {
  static const _markets = [
    ('us', 'Mercado Americano'),
  ];

  var _market = 'us';
  var _sortBy = 'payment';
  var _loading = true;
  String? _error;
  List<DividendCalendarEntry> _items = const [];

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
    try {
      final response = await dividendCalendarRepository.fetchCalendar(
        market: _market,
        sortBy: _sortBy,
      );
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar a agenda.';
        _loading = false;
      });
    }
  }

  void _setMarket(String market) {
    if (_market == market) return;
    setState(() => _market = market);
    _load();
  }

  void _setSortBy(String sortBy) {
    if (_sortBy == sortBy) return;
    setState(() => _sortBy = sortBy);
    _load();
  }

  void _openAsset(DividendCalendarEntry entry) {
    openTickerDetail(
      context,
      ticker: entry.symbol,
      globalMarketRepo: widget.globalMarketRepository,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const subtitle = 'Ações americanas — NYSE e NASDAQ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de dividendos'),
        actions: const [ShellHomeButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: _markets
                  .map(
                    (item) => ButtonSegment<String>(
                      value: item.$1,
                      label: Text(item.$2),
                    ),
                  )
                  .toList(),
              selected: {_market},
              onSelectionChanged: (value) => _setMarket(value.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Por pagamento'),
                    selected: _sortBy == 'payment',
                    onSelected: (_) => _setSortBy('payment'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Por data com'),
                    selected: _sortBy == 'com',
                    onSelected: (_) => _setSortBy('com'),
                  ),
                ),
              ],
            ),
            if (_market == 'br') ...[
              const SizedBox(height: 8),
              Text(
                'Agenda de proventos da B3 (ações, BDRs e FIIs). '
                'A data com pode variar um dia útil em relação a outros sites.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              const _EmptyState()
            else
              _AgendaTable(
                items: _items,
                onTap: _openAsset,
              ),
          ],
        ),
      ),
    );
  }
}

class _AgendaTable extends StatelessWidget {
  const _AgendaTable({
    required this.items,
    required this.onTap,
  });

  final List<DividendCalendarEntry> items;
  final void Function(DividendCalendarEntry entry) onTap;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(flex: 30, child: Text('Empresa', style: headerStyle)),
                Expanded(flex: 18, child: Text('Data Com', style: headerStyle)),
                Expanded(flex: 20, child: Text('Pagamento', style: headerStyle)),
                Expanded(flex: 16, child: Text('Tipo', style: headerStyle)),
                Expanded(
                  flex: 16,
                  child: Text('Valor', style: headerStyle, textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < items.length; i++) ...[
            _AgendaRow(entry: items[i], onTap: () => onTap(items[i])),
            if (i < items.length - 1) const Divider(height: 1, indent: 12, endIndent: 12),
          ],
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.entry,
    required this.onTap,
  });

  final DividendCalendarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cellStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final valueStyle = cellStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.symbol,
                    style: cellStyle?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.companyName.isNotEmpty)
                    Text(
                      entry.companyName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(formatAgendaDate(entry.comDate), style: cellStyle),
            ),
            Expanded(
              flex: 20,
              child: Text(formatAgendaDate(entry.paymentDate), style: cellStyle),
            ),
            Expanded(
              flex: 16,
              child: Text(
                entry.dividendType,
                style: cellStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                formatAgendaAmount(entry),
                style: valueStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum provento confirmado no período.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
