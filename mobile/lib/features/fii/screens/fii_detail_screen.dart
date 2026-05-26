import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
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
import 'package:rico_investidor/features/fii/widgets/fii_properties_state_pie_card.dart';
import 'package:rico_investidor/features/fii/utils/fii_property_state.dart';
import 'package:rico_investidor/features/fii/widgets/fii_quote_hero_card.dart';
import 'package:rico_investidor/features/fii/widgets/fii_simulator_card.dart';
import 'package:rico_investidor/models/fii_models.dart';

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
  late Future<FiiDetailBundle> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<FiiDetailBundle> _load() async {
    final detail = widget.initialDetail ?? await widget.repository.getDetail(widget.ticker);

    FiiDistributions? distributions;
    FiiHistoryResponse? history;
    FiiTenantsResponse? tenants;

    try {
      distributions = await widget.repository.getDistributions(widget.ticker, years: 15);
    } catch (_) {}

    try {
      history = await widget.repository.getHistory(widget.ticker, limit: 120);
    } catch (_) {}

    try {
      tenants = await widget.repository.getTenants(widget.ticker);
    } catch (_) {}

    return FiiDetailBundle(
      detail: detail,
      distributions: distributions,
      history: history,
      tenants: tenants,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticker),
        actions: [
          const ShellHomeButton(),
          IconButton(
            tooltip: 'Comparar',
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
      body: FutureBuilder<FiiDetailBundle>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _loadFuture = _load()),
            );
          }

          return _FiiDetailBody(bundle: snapshot.data!, repository: widget.repository);
        },
      ),
    );
  }
}

class FiiDetailBundle {
  const FiiDetailBundle({
    required this.detail,
    this.distributions,
    this.history,
    this.tenants,
  });

  final FiiDetail detail;
  final FiiDistributions? distributions;
  final FiiHistoryResponse? history;
  final FiiTenantsResponse? tenants;
}

class _FiiDetailBody extends StatelessWidget {
  const _FiiDetailBody({required this.bundle, required this.repository});

  final FiiDetailBundle bundle;
  final FiiRepository repository;

  @override
  Widget build(BuildContext context) {
    final detail = bundle.detail;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          detail.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Center(child: FiiHeaderChips(detail: detail)),
        if (detail.referenceDate != null) ...[
          const SizedBox(height: 8),
          Text(
            'Referência: ${detail.referenceDate}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        FiiQuoteHeroCard(
          detail: detail,
          history: bundle.history?.history,
        ),
        if (bundle.history != null && bundle.history!.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          FiiReturnsCard(
            history: bundle.history!.history,
            currentPrice: detail.closePrice,
            payments: bundle.distributions?.payments ?? const [],
          ),
          const SizedBox(height: 12),
          FiiMarketSentimentCard(
            history: bundle.history!.history,
            currentPrice: detail.closePrice,
          ),
          const SizedBox(height: 12),
          FiiMagicNumberCard(
            detail: detail,
            distributions: bundle.distributions,
            history: bundle.history!.history,
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
        ),
        const SizedBox(height: 20),
        const FiiSectionHeader('Operacional'),
        const SizedBox(height: 8),
        FiiMetricsGrid(
          metrics: [
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
          const FiiSectionHeader('Composição do patrimônio'),
          const SizedBox(height: 8),
          FiiCompositionCard(composition: detail.assetComposition!),
        ],
        if (detail.topProperties.isNotEmpty) ...[
          const SizedBox(height: 20),
          FiiSectionHeader(
            'Principais imóveis',
            subtitle: detail.propertyReferenceDate != null
                ? 'Referência: ${detail.propertyReferenceDate}'
                : null,
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
                ? 'Referência: ${bundle.tenants!.referenceDate}'
                : null,
          ),
          const SizedBox(height: 8),
          FiiTenantsCard(tenants: bundle.tenants!),
        ],
        if (bundle.history != null && bundle.history!.history.isNotEmpty) ...[
          const SizedBox(height: 20),
          const FiiSectionHeader('Simulador de investimento'),
          const SizedBox(height: 8),
          FiiSimulatorCard(
            detail: detail,
            history: bundle.history!.history,
            payments: bundle.distributions?.payments ?? const [],
          ),
        ],
        if (bundle.distributions != null) ...[
          const SizedBox(height: 20),
          const FiiSectionHeader('Proventos'),
          const SizedBox(height: 8),
          FiiDistributionsSection(distributions: bundle.distributions!),
          if (bundle.distributions!.annualSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            FiiDistributionsChart(annualSummary: bundle.distributions!.annualSummary),
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
        const SizedBox(height: 12),
        Text(
          'Fonte: ${detail.provider.toUpperCase()}',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
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
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'API: ${ApiConfig.baseUrl}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
