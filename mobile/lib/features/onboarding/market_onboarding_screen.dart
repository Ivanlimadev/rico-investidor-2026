import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

/// Seleção do país de bolsa preferido — usada no primeiro acesso e ao trocar.
class MarketOnboardingScreen extends StatefulWidget {
  const MarketOnboardingScreen({
    super.key,
    required this.repository,
    required this.onConfirm,
    this.currentCode,
    this.allowBack = false,
  });

  final GlobalMarketRepository repository;
  final ValueChanged<MarketPreference> onConfirm;
  final String? currentCode;
  final bool allowBack;

  @override
  State<MarketOnboardingScreen> createState() => _MarketOnboardingScreenState();
}

class _MarketOnboardingScreenState extends State<MarketOnboardingScreen> {
  late Future<WorldExchangesResponseDto> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listWorldExchanges();
  }

  void _retry() {
    setState(() {
      _future = widget.repository.listWorldExchanges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.allowBack,
        title: const Text('Escolha seu mercado'),
      ),
      body: SafeArea(
        child: FutureBuilder<WorldExchangesResponseDto>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar os mercados.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _retry, child: const Text('Tentar novamente')),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final groups = [...data.priorityCountries, ...data.otherCountries];
            final currentCode = widget.currentCode?.toUpperCase();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: groups.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Qual mercado você quer acompanhar?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sua tela inicial vai destacar os ativos, rankings e variações deste país. Você pode trocar quando quiser.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }

                final group = groups[index - 1];
                final selected = currentCode != null &&
                    group.countryCode.toUpperCase() == currentCode;
                return _CountryOptionCard(
                  group: group,
                  selected: selected,
                  onTap: () => widget.onConfirm(
                    MarketPreference(
                      code: group.countryCode.toUpperCase(),
                      name: group.countryName,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CountryOptionCard extends StatelessWidget {
  const _CountryOptionCard({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final CountryExchangesGroupDto group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exchangeLabel = group.exchangeCount == 1
        ? '1 bolsa'
        : '${group.exchangeCount} bolsas';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CountryFlagImage(countryCode: group.countryCode, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.countryName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(exchangeLabel, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
