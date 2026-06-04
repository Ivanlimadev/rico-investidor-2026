import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/screens/country_hub_screen.dart';
import 'package:rico_investidor/features/home/screens/brazilian_market_hub_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';

class WorldExchangesHubScreen extends StatefulWidget {
  const WorldExchangesHubScreen({
    super.key,
    required this.repository,
    required this.fiiRepository,
    required this.quoteRepository,
  });

  final GlobalMarketRepository repository;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  @override
  State<WorldExchangesHubScreen> createState() => _WorldExchangesHubScreenState();
}

class _WorldExchangesHubScreenState extends State<WorldExchangesHubScreen> {
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
        title: const Text('Mercados'),
      ),
      body: FutureBuilder<WorldExchangesResponseDto>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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

          if (groups.isEmpty) {
            return const Center(child: Text('Nenhum mercado disponível no momento.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: groups.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  '${data.totalCountries > 0 ? data.totalCountries : groups.length} mercados · Brasil e Estados Unidos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                );
              }

              final group = groups[index - 1];
              return _CountryMarketCard(
                group: group,
                repository: widget.repository,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
              );
            },
          );
        },
      ),
    );
  }
}

class _CountryMarketCard extends StatelessWidget {
  const _CountryMarketCard({
    required this.group,
    required this.repository,
    required this.fiiRepository,
    required this.quoteRepository,
  });

  final CountryExchangesGroupDto group;
  final GlobalMarketRepository repository;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  void _openCountry(BuildContext context) {
    final code = group.countryCode.toUpperCase();
    if (code == 'BR') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BrazilianMarketHubScreen(
            fiiRepository: fiiRepository,
            quoteRepository: quoteRepository,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryHubScreen(
          countryCode: group.countryCode,
          countryName: group.countryName,
          repository: repository,
          fiiRepository: fiiRepository,
          quoteRepository: quoteRepository,
          exchangeCount: group.exchangeCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCountry(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CountryFlagImage(countryCode: group.countryCode, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  group.countryName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
