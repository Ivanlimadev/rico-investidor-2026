import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_data_freshness.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/fii/widgets/fii_data_freshness_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_about_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_quote_chart_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_detail_sections.dart';
import 'package:rico_investidor/features/fii/screens/fii_compare_screen.dart';
import 'package:rico_investidor/features/fii/widgets/fii_fund_costs_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_history_charts.dart';
import 'package:rico_investidor/features/fii/widgets/fii_market_sentiment_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_magic_number_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_recent_dividends_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_related_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_returns_card.dart';
import 'package:rico_investidor/features/fii/utils/fii_assets_labels.dart';
import 'package:rico_investidor/features/fii/widgets/fii_properties_state_pie_card.dart';
import 'package:rico_investidor/features/fii/utils/fii_property_state.dart';
import 'package:rico_investidor/features/fii/widgets/fii_quote_hero_card.dart';
import 'package:rico_investidor/core/widgets/last_dividend_card.dart';
import 'package:rico_investidor/core/widgets/what_if_investment_card.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/market_category.dart';

class FiiDetailScreen extends StatefulWidget {
  const FiiDetailScreen({
    super.key,
    required this.ticker,
    required this.repository,
    this.initialDetail,
  });

  final String ticker;
  final FiiRepository repository;
  final FiiDetail? initialDetail;

  @override
  State<FiiDetailScreen> createState() => _FiiDetailScreenState();
}

class _FiiDetailScreenState extends State<FiiDetailScreen> {
  FiiDetail? _detail;
  FiiDistributions? _distributions;
  FiiHistoryResponse? _history;
  FiiCandlesResponse? _candles;
  FiiTenantsResponse? _tenants;
  Object? _detailError;
  bool _detailLoading = true;
  bool _extrasLoading = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.initialDetail != null) {
      setState(() {
        _detail = widget.initialDetail;
        _detailLoading = false;
        _extrasLoading = true;
      });
      await _loadExtras();
      return;
    }

    try {
      final detail = await widget.repository.getDetail(widget.ticker);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailLoading = false;
        _extrasLoading = true;
      });
      await _loadExtras();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailError = error;
        _detailLoading = false;
        _extrasLoading = false;
      });
    }
  }

  Future<void> _loadExtras() async {
    final results = await Future.wait<Object?>([
      _safe(
        () => widget.repository.getDistributions(
          widget.ticker,
          years: FiiRepository.extendedDistributionYears,
        ),
      ),
      _safe(
        () => widget.repository.getHistory(
          widget.ticker,
          limit: FiiRepository.extendedHistoryLimit,
        ),
      ),
      _safe(
        () => widget.repository.getCandles(
          widget.ticker,
          limit: FiiRepository.extendedCandleLimit,
        ),
      ),
    ]);

    if (!mounted) return;
    setState(() {
      _distributions = results[0] as FiiDistributions?;
      _history = results[1] as FiiHistoryResponse?;
      _candles = results[2] as FiiCandlesResponse?;
      _extrasLoading = false;
    });
  }

  Future<T?> _safe<T>(Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    setState(() {
      _detail = null;
      _distributions = null;
      _history = null;
      _candles = null;
      _tenants = null;
      _detailError = null;
      _detailLoading = true;
      _extrasLoading = false;
    });
    _bootstrap();
  }

  Future<void> _onRefresh() async {
    widget.repository.invalidateDetail(widget.ticker);
    setState(() => _extrasLoading = true);
    try {
      final detail = await widget.repository.getDetail(widget.ticker);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailError = null;
      });
      await _loadExtras();
    } catch (_) {
      if (!mounted) return;
      setState(() => _extrasLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionAsset = _detail == null
        ? null
        : AssetItem(
            symbol: _detail!.ticker,
            name: _detail!.name,
            category: MarketCategory.fiis,
            price: _detail!.closePrice ?? 0,
            changePercent: 0,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticker),
        actions: [
          const ShellHomeButton(),
          if (actionAsset != null) ...AssetQuickActions.appBarActions(context, actionAsset),
          IconButton(
            tooltip: 'Comparar FIIs',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FiiCompareScreen(
                  repository: widget.repository,
                  initialTickers: [widget.ticker],
                ),
              ),
            ),
            icon: const Icon(Icons.compare_arrows),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detailError != null || _detail == null) {
      return _ErrorState(onRetry: _retry);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _onRefresh,
          child: _FiiDetailBody(
            bundle: FiiDetailBundle(
              detail: _detail!,
              distributions: _distributions,
              history: _history,
              candles: _candles,
              tenants: _tenants,
            ),
            repository: widget.repository,
          ),
        ),
        if (_extrasLoading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

class FiiDetailBundle {
  const FiiDetailBundle({
    required this.detail,
    this.distributions,
    this.history,
    this.candles,
    this.tenants,
  });

  final FiiDetail detail;
  final FiiDistributions? distributions;
  final FiiHistoryResponse? history;
  final FiiCandlesResponse? candles;
  final FiiTenantsResponse? tenants;

  List<FiiHistoryPoint> get historyPoints => history?.history ?? const [];

  List<FiiCandleBar> get candleBars => candles?.candles ?? const [];

  bool get hasReturnData => historyPoints.isNotEmpty || candleBars.isNotEmpty;
}

class _FiiDetailBody extends StatelessWidget {
  const _FiiDetailBody({required this.bundle, required this.repository});

  final FiiDetailBundle bundle;
  final FiiRepository repository;

  @override
  Widget build(BuildContext context) {
    final detail = bundle.detail;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          detail.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Center(child: FiiHeaderChips(detail: detail)),
        const SizedBox(height: 12),
        FiiDataFreshnessCard(
          reportReferenceDate: detail.referenceDate,
          candles: bundle.candleBars,
        ),
        const SizedBox(height: 16),
        FiiQuoteHeroCard(
          detail: detail,
          history: bundle.historyPoints,
          candles: bundle.candleBars,
        ),
        if (bundle.distributions != null &&
            lastPaidPayment(bundle.distributions!.payments) != null) ...[
          const SizedBox(height: 12),
          LastDividendCard(
            payments: bundle.distributions!.payments,
            dividendYield12m: detail.dividendYieldTtm ?? bundle.distributions!.dividendYieldTtm,
            dateStyle: LastDividendDateStyle.fii,
            perShareLabel: 'cota',
          ),
        ],
        if (bundle.hasReturnData) ...[
          const SizedBox(height: 12),
          FiiReturnsCard(
            history: bundle.historyPoints,
            candles: bundle.candleBars,
            currentPrice: detail.closePrice,
            payments: bundle.distributions?.payments ?? const [],
          ),
          const SizedBox(height: 12),
          FiiMarketSentimentCard(
            history: bundle.historyPoints,
            candles: bundle.candleBars,
            currentPrice: detail.closePrice,
          ),
          const SizedBox(height: 12),
          FiiMagicNumberCard(
            detail: detail,
            distributions: bundle.distributions,
            history: bundle.historyPoints,
          ),
          if (bundle.distributions != null && bundle.distributions!.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            FiiRecentDividendsCard(payments: bundle.distributions!.payments),
          ],
        ],
        const SizedBox(height: 12),
        FiiQuoteChartCard(
          ticker: detail.ticker,
          repository: repository,
          initialCandles: bundle.candleBars,
        ),
        const SizedBox(height: 20),
        const FiiSectionHeader('Operacional'),
        if (fiiOperacionalHint(detail) != null) ...[
          const SizedBox(height: 6),
          Text(
            fiiOperacionalHint(detail)!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
        ],
        const SizedBox(height: 8),
        FiiMetricsGrid(
          metrics: [
            if (detail.assetComposition?.criPct != null && detail.assetComposition!.criPct! > 0)
              FiiMetricItem(
                label: 'CRI',
                value: formatPct(detail.assetComposition!.criPct!),
              ),
            FiiMetricItem(
              label: 'Vacância',
              value: detail.vacancyPct != null ? formatPct(detail.vacancyPct!) : null,
            ),
            FiiMetricItem(
              label: 'Inadimplência',
              value: detail.delinquencyPct != null ? formatPct(detail.delinquencyPct!) : null,
            ),
            FiiMetricItem(
              label: 'Ocupação',
              value: detail.leasedPct != null ? formatPct(detail.leasedPct!) : null,
            ),
            FiiMetricItem(label: 'Imóveis', value: detail.propertyCount?.toString()),
            FiiMetricItem(
              label: 'Área total',
              value: detail.totalAreaSqm != null ? formatAreaSqm(detail.totalAreaSqm!) : null,
            ),
          ],
        ),
        if (detail.feesPaidLastMonth != null) ...[
          const SizedBox(height: 12),
          FiiFundCostsCard(detail: detail),
        ],
        if (detail.assetComposition != null &&
            detail.assetComposition!.nonZeroItems().isNotEmpty) ...[
          const SizedBox(height: 20),
          const SizedBox(height: 8),
          FiiCompositionCard(
            composition: detail.assetComposition!,
            fundType: detail.fundType,
          ),
        ],
        if (detail.topProperties.isNotEmpty) ...[
          const SizedBox(height: 20),
          FiiSectionHeader(
            fiiPatrimonySectionTitle(detail),
            subtitle: fiiPatrimonySectionSubtitle(detail),
          ),
          const SizedBox(height: 8),
          FiiPropertiesCard(
            properties: detail.topProperties,
            referenceDate: detail.propertyReferenceDate,
          ),
          if (fiiHasRealEstateProperties(detail)) ...[
            const SizedBox(height: 12),
            FiiPropertiesStatePieCard(
              properties: detail.topProperties,
              totalPropertyCount: detail.propertyCount,
            ),
          ],
        ],
        if (bundle.tenants != null && bundle.tenants!.sectors.isNotEmpty) ...[
          const SizedBox(height: 20),
          FiiSectionHeader(
            'Inquilinos por setor',
            subtitle: bundle.tenants!.referenceDate != null
                ? cvmReportReferenceLabel(bundle.tenants!.referenceDate)
                : null,
          ),
          const SizedBox(height: 8),
          FiiTenantsCard(tenants: bundle.tenants!),
        ],
        if (bundle.history != null && bundle.history!.history.isNotEmpty) ...[
          const SizedBox(height: 20),
          const FiiSectionHeader('Quanto teria investido?'),
          const SizedBox(height: 8),
          WhatIfInvestmentCard(
            currentPrice: detail.closePrice,
            history: bundle.history!.history,
            candles: bundle.candleBars,
            payments: bundle.distributions?.payments ?? const [],
            unitLabel: 'cota',
          ),
        ],
        if (bundle.distributions != null) ...[
          const SizedBox(height: 20),
          const FiiSectionHeader('Proventos'),
          const SizedBox(height: 8),
          FiiDistributionsSection(distributions: bundle.distributions!),
          if (bundle.distributions!.annualSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            FiiDistributionsChart(
              annualSummary: bundle.distributions!.annualSummary,
              payments: bundle.distributions!.payments,
              perShareLabel: 'cota',
            ),
          ],
        ],
        const SizedBox(height: 20),
        FiiRelatedCard(detail: detail, repository: repository),
        const SizedBox(height: 20),
        const FiiSectionHeader('Perfil do fundo'),
        const SizedBox(height: 8),
        FiiInfoCard(
          rows: [
            FiiInfoRow(label: 'Administrador', value: detail.administrator),
            FiiInfoRow(label: 'CNPJ admin.', value: detail.administratorCnpj),
            FiiInfoRow(label: 'Mandato', value: detail.mandate),
            FiiInfoRow(label: 'Início', value: detail.inceptionDate),
            FiiInfoRow(label: 'Prazo', value: detail.durationType),
            FiiInfoRow(label: 'Público-alvo', value: detail.targetInvestors),
            FiiInfoRow(label: 'Site', value: detail.website),
            FiiInfoRow(label: 'E-mail', value: detail.email),
            FiiInfoRow(
              label: 'Cotas emitidas',
              value: detail.sharesOutstanding != null
                  ? formatSharesOutstanding(detail.sharesOutstanding!)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const FiiSectionHeader('Sobre o fundo'),
        const SizedBox(height: 8),
        FiiAboutCard(detail: detail, tenants: bundle.tenants),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Não foi possível carregar o FII',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Verifique sua conexão e tente novamente.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
