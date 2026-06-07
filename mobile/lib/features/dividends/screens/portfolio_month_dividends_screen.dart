import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/core/utils/portfolio_balance.dart';
import 'package:rico_investidor/features/portfolio/utils/portfolio_dividend_mapper.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/services/portfolio_dividend_service.dart';
import 'package:rico_investidor/services/portfolio_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

void openPortfolioMonthDividendsScreen(
  BuildContext context, {
  required PortfolioState portfolio,
  VoidCallback? onPortfolioChanged,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PortfolioMonthDividendsScreen(
        portfolio: portfolio,
        onPortfolioChanged: onPortfolioChanged,
      ),
    ),
  );
}

class PortfolioMonthDividendsScreen extends StatefulWidget {
  const PortfolioMonthDividendsScreen({
    super.key,
    required this.portfolio,
    this.onPortfolioChanged,
  });

  final PortfolioState portfolio;
  final VoidCallback? onPortfolioChanged;

  @override
  State<PortfolioMonthDividendsScreen> createState() => _PortfolioMonthDividendsScreenState();
}

class _PortfolioMonthDividendsScreenState extends State<PortfolioMonthDividendsScreen> {
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncDividends();
  }

  Future<void> _syncDividends() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    try {
      final result = await portfolioDividendService.syncPortfolioDividends(widget.portfolio);
      if (!mounted) return;
      setState(() {
        _syncing = false;
        if (result.totalFailureFor(widget.portfolio.holdings.length)) {
          _syncError = 'Não foi possível carregar os proventos da carteira.';
        } else if (result.failedSymbols.isNotEmpty) {
          _syncError = 'Parcial: falhou em ${result.failedSymbols.join(', ')}.';
        }
      });
      if (result.completed) {
        widget.onPortfolioChanged?.call();
        await PortfolioStorage().save(
          holdings: widget.portfolio.holdings,
          dividends: widget.portfolio.dividends,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncError = 'Não foi possível carregar os proventos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = monthNamePt(DateTime.now().month);
    final items = widget.portfolio.dividendsThisMonthDetailed();
    final preference = AppShellScope.of(context).preferredMarket;
    final total = widget.portfolio.monthlyDividendsFor(preference);
    final projected = items.where((item) => item.isProjected).fold<double>(
          0,
          (sum, item) => sum + _amountInUsd(item),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dividendos no mês'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _syncing ? null : _syncDividends,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const ShellHomeButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncDividends,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              '$monthLabel ${DateTime.now().year} · ativos na carteira',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total estimado', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(
                      formatUsd(total),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                    ),
                    if (projected > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Inclui ${formatUsd(projected)} previstos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Cálculo: valor por ação/cota (API) × quantidade na carteira.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (_syncError != null) ...[
              const SizedBox(height: 12),
              Text(
                _syncError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 20),
            if (widget.portfolio.holdings.isEmpty)
              const _EmptyHoldingsCard()
            else if (_syncing && items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const _EmptyMonthCard()
            else
              ...items.map(
                (payment) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PortfolioMonthDividendTile(
                    payment: payment,
                    onTap: () => openTickerDetail(context, ticker: payment.symbol),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _amountInUsd(DividendPayment payment) {
    return dividendAmountInCurrency(
      payment,
      target: HoldingCurrency.usd,
      usdBrlRate: widget.portfolio.usdBrlRate,
    );
  }
}

class _PortfolioMonthDividendTile extends StatelessWidget {
  const _PortfolioMonthDividendTile({
    required this.payment,
    required this.onTap,
  });

  final DividendPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unit = quantityUnitLabel(payment.symbol);
    final qty = payment.quantity;
    final perShare = payment.amountPerShare;
    final holdingCurrency = holdingCurrencyForSymbol(payment.symbol);
    final amountLabel = holdingCurrency.format(payment.amount);
    final perShareLabel = perShare == null ? '—' : holdingCurrency.format(perShare);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AssetLogo(
                    symbol: payment.symbol,
                    size: 36,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.symbol,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          payment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (payment.isProjected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Previsto',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Posição',
                value: qty == null
                    ? '—'
                    : '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $unit',
              ),
              _DetailRow(label: 'Data com', value: formatDividendDayOrDash(payment.comDate)),
              _DetailRow(label: 'Pagamento', value: formatDividendDay(payment.date)),
              _DetailRow(label: 'Tipo', value: payment.kind ?? 'Provento'),
              _DetailRow(label: 'Valor / $unit', value: perShareLabel),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Você recebe',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Text(
                    amountLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.positive,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyHoldingsCard extends StatelessWidget {
  const _EmptyHoldingsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Adicione ativos à carteira para ver proventos estimados.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyMonthCard extends StatelessWidget {
  const _EmptyMonthCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Nenhum provento confirmado ou previsto neste mês para os ativos da sua carteira.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
