import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_live_market_list.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/screens/crypto_explore_screen.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/screens/us_market_list_screen.dart';
import 'package:rico_investidor/features/currency/data/currency_repository.dart';
import 'package:rico_investidor/features/currency/screens/currency_explore_screen.dart';
import 'package:rico_investidor/features/indices/data/indices_repository.dart';
import 'package:rico_investidor/features/indices/screens/index_explore_screen.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';
import 'package:rico_investidor/features/treasury/data/treasury_repository.dart';
import 'package:rico_investidor/features/treasury/screens/treasury_explore_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_list_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/screens/stock_compare_screen.dart';
import 'package:rico_investidor/features/quotes/screens/stock_explore_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/models/market_category.dart';

class MarketListScreen extends StatefulWidget {
  const MarketListScreen({
    super.key,
    required this.category,
    required this.fiiRepository,
    required this.quoteRepository,
    this.globalMarketRepository,
  });

  final MarketCategory category;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final GlobalMarketRepository? globalMarketRepository;

  @override
  State<MarketListScreen> createState() => _MarketListScreenState();
}

class _MarketListScreenState extends State<MarketListScreen> {
  late Future<List<AssetItem>> _loadFuture;

  GlobalMarketRepository get _globalMarketRepository =>
      widget.globalMarketRepository ?? globalMarketRepository;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAssets();
  }

  Future<List<AssetItem>> _loadAssets() async {
    if (widget.category == MarketCategory.fiis) return const [];

    if (widget.category == MarketCategory.moeda) {
      final items = await currencyRepository.listFeaturedAssets();
      if (items.isEmpty) {
        throw StateError('Lista vazia');
      }
      return items;
    }

    if (widget.category == MarketCategory.tesouroDireto) {
      final items = await treasuryRepository.listFeaturedAssets();
      if (items.isEmpty) {
        throw StateError('Lista vazia');
      }
      return items;
    }

    if (widget.category == MarketCategory.indices) {
      final items = await indicesRepository.listFeaturedAssets();
      if (items.isEmpty) {
        throw StateError('Lista vazia');
      }
      return items;
    }

    if (widget.category == MarketCategory.cripto) {
      final items = await cryptoRepository.listFeaturedAssets();
      if (items.isEmpty) {
        throw StateError('Lista vazia');
      }
      return items;
    }

    if (widget.category == MarketCategory.stocks || widget.category == MarketCategory.reits) {
      final items = await _globalMarketRepository.listByCategory(widget.category);
      if (items.isEmpty) {
        throw StateError('Lista vazia');
      }
      return items;
    }

    if (widget.quoteRepository.supportsCategory(widget.category)) {
      final items = await widget.quoteRepository.listByCategory(widget.category);
      if (items.isEmpty) {
        throw StateError('Lista vazia');
      }
      return items;
    }

    throw StateError('Categoria sem dados ao vivo');
  }

  Future<void> _retry() async {
    setState(() {
      _loadFuture = _loadAssets();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.category == MarketCategory.fiis) {
      return FiiListScreen(repository: widget.fiiRepository);
    }

    if (widget.category == MarketCategory.stocks || widget.category == MarketCategory.reits) {
      return UsMarketListScreen(
        category: widget.category,
        repository: _globalMarketRepository,
        fiiRepository: widget.fiiRepository,
        quoteRepository: widget.quoteRepository,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
        actions: [
          if (widget.category == MarketCategory.moeda)
            IconButton(
              tooltip: 'Explorar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CurrencyExploreScreen(
                    fiiRepository: widget.fiiRepository,
                    quoteRepository: widget.quoteRepository,
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
          if (widget.category == MarketCategory.tesouroDireto)
            IconButton(
              tooltip: 'Explorar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TreasuryExploreScreen(
                    fiiRepository: widget.fiiRepository,
                    quoteRepository: widget.quoteRepository,
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
          if (widget.category == MarketCategory.indices)
            IconButton(
              tooltip: 'Explorar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => IndexExploreScreen(
                    fiiRepository: widget.fiiRepository,
                    quoteRepository: widget.quoteRepository,
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
          if (widget.category == MarketCategory.cripto)
            IconButton(
              tooltip: 'Explorar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CryptoExploreScreen(
                    fiiRepository: widget.fiiRepository,
                    quoteRepository: widget.quoteRepository,
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
          if (widget.quoteRepository.supportsCategory(widget.category)) ...[
            IconButton(
              tooltip: 'Explorar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StockExploreScreen(
                    repository: widget.quoteRepository,
                    fiiRepository: widget.fiiRepository,
                    category: widget.category,
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              tooltip: 'Comparar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StockCompareScreen(repository: widget.quoteRepository),
                ),
              ),
              icon: const Icon(Icons.compare_arrows),
            ),
          ],
          const ShellHomeButton(),
        ],
      ),
      body: FutureBuilder<List<AssetItem>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível carregar ${widget.category.title.toLowerCase()}.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final assets = snapshot.data ?? const [];
          if (assets.isEmpty) {
            return Center(
              child: Text(
                'Nenhum ativo nesta categoria ainda.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: widget.category == MarketCategory.cripto
                    ? CryptoLiveMarketList(
                        assets: assets,
                        fiiRepository: widget.fiiRepository,
                        quoteRepository: widget.quoteRepository,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: assets.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _AssetListTile(
                          asset: assets[index],
                          category: widget.category,
                          onTap: () => openAssetDetail(
                            context,
                            asset: assets[index],
                            fiiRepository: widget.fiiRepository,
                            quoteRepository: widget.quoteRepository,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AssetListTile extends StatelessWidget {
  const _AssetListTile({
    required this.asset,
    required this.onTap,
    required this.category,
  });

  final AssetItem asset;
  final VoidCallback onTap;
  final MarketCategory category;

  @override
  Widget build(BuildContext context) {
    final changeColor = asset.isPositive ? AppColors.positive : AppColors.negative;
    final isTreasury = category == MarketCategory.tesouroDireto;
    final isIndex = category == MarketCategory.indices;
    final isCrypto = category == MarketCategory.cripto;
    final title = isTreasury || isIndex ? asset.name : asset.symbol;
    final subtitle = isTreasury || isIndex ? asset.symbol : asset.name;

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: AssetListLeading(symbol: asset.symbol, logoUrl: asset.logoUrl),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              category == MarketCategory.moeda
                  ? formatCurrencyRate(asset.price, asset.symbol)
                  : category == MarketCategory.indices
                      ? formatIndexPoints(asset.price)
                      : isCrypto
                          ? formatCryptoPrice(asset.price)
                          : formatBrl(asset.price),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (!isTreasury)
              Text(
                '${asset.isPositive ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
                style: TextStyle(color: changeColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
