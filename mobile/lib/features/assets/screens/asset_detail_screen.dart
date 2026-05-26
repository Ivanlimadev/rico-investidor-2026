import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/assets/data/asset_repository.dart';
import 'package:rico_investidor/features/assets/models/asset_detail.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_detail_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/screens/stock_detail_screen.dart';

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    super.key,
    required this.ticker,
    required this.fiiRepository,
    required this.quoteRepository,
    this.repository,
  });

  final String ticker;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final AssetRepository? repository;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late Future<AssetDetailDto> _loadFuture;

  AssetRepository get _repository => widget.repository ?? assetRepository;

  @override
  void initState() {
    super.initState();
    _loadFuture = _repository.getDetail(widget.ticker);
  }

  void _retry() {
    setState(() => _loadFuture = _repository.getDetail(widget.ticker));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetDetailDto>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.ticker),
              actions: const [ShellHomeButton()],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.ticker),
              actions: const [ShellHomeButton()],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Não foi possível carregar ${widget.ticker}.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final asset = snapshot.data!;
        if (asset.isFii && asset.fii != null) {
          return FiiDetailScreen(
            ticker: asset.ticker,
            repository: widget.fiiRepository,
            initialDetail: asset.fii,
          );
        }

        if (asset.stock != null) {
          return StockDetailScreen(
            ticker: asset.ticker,
            category: asset.category,
            repository: widget.quoteRepository,
            initialDetail: asset.stock,
            notes: asset.notes,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.ticker),
            actions: const [ShellHomeButton()],
          ),
          body: Center(
            child: Text(
              'Detalhe de ${asset.ticker} indisponível.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        );
      },
    );
  }
}
