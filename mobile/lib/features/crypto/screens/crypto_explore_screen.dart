import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/crypto/data/crypto_mini_ticker_stream.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/utils/crypto_explore_presets.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class CryptoExploreScreen extends StatefulWidget {
  const CryptoExploreScreen({
    super.key,
    this.repository,
    this.fiiRepository,
    this.quoteRepository,
  });

  final CryptoRepository? repository;
  final FiiRepository? fiiRepository;
  final QuoteRepository? quoteRepository;

  @override
  State<CryptoExploreScreen> createState() => _CryptoExploreScreenState();
}

class _CryptoExploreScreenState extends State<CryptoExploreScreen> {
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();

  CryptoRepository get _repository => widget.repository ?? cryptoRepository;

  UnifiedAssetSearchSnapshot _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();
  String _groupId = cryptoExploreGroups.first.id;
  List<CryptoQuoteDto> _items = [];
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  CryptoMiniTickerStream? _tickerStream;
  final _liveQuotes = <String, CryptoLiveQuote>{};

  bool get _canLoadMore => _page < _totalPages && !_loading && !_loadingMore;

  @override
  void initState() {
    super.initState();
    _tickerStream = CryptoMiniTickerStream(
      onQuote: (quote) {
        if (!mounted) return;
        setState(() => _liveQuotes[quote.symbol] = quote);
      },
    );
    _load(reset: true);
  }

  @override
  void dispose() {
    _unifiedSearch.dispose();
    _searchController.dispose();
    _tickerStream?.close();
    super.dispose();
  }

  void _syncTicker() {
    if (_items.isEmpty) return;
    _tickerStream?.connect(_items.map((item) => item.symbol));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _items = [];
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final page = reset ? 1 : _page + 1;

    try {
      final response = await _repository.explore(
        group: _groupId,
        page: page,
        limit: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        if (reset) {
          _items = response.items;
        } else {
          _items = [..._items, ...response.items];
        }
        _page = response.page;
        _total = response.total;
        _totalPages = response.totalPages;
        _loading = false;
        _loadingMore = false;
      });
      precacheCryptoLogos(response.items.map((item) => item.symbol));
      _syncTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _selectGroup(String groupId) {
    if (_groupId == groupId || _searchSnapshot.active) return;
    setState(() => _groupId = groupId);
    _load(reset: true);
  }

  void _onSearchChanged(String value) {
    _unifiedSearch.search(value, (snapshot) {
      if (!mounted) return;
      setState(() => _searchSnapshot = snapshot);
      if (!snapshot.active) {
        _load(reset: true);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Cripto'),
        actions: const [ShellHomeButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _searchController,
              hintText: kUnifiedAssetSearchHint,
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchSnapshot.query.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpar',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: _onSearchChanged,
            ),
          ),
          if (!_searchSnapshot.active) ...[
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: cryptoExploreGroups.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final group = cryptoExploreGroups[index];
                  return FilterChip(
                    label: Text(group.label),
                    selected: _groupId == group.id,
                    onSelected: (_) => _selectGroup(group.id),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '$_total moedas · página $_page/$_totalPages · USD · Binance',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                _searchSnapshot.loading
                    ? 'Buscando em todas as classes…'
                    : '${_searchSnapshot.results.length} resultados · busca global',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_searchSnapshot.active) {
      return UnifiedAssetResultsBody(
        snapshot: _searchSnapshot,
        fiiRepository: widget.fiiRepository ?? fiiRepository,
        quoteRepository: widget.quoteRepository ?? quoteRepository,
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Nenhuma criptomoeda encontrada neste filtro.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length + (_canLoadMore || _loadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : () => _load(reset: false),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(_loadingMore ? 'Carregando…' : 'Carregar mais'),
            ),
          );
        }

        final quote = _items[index];
        final live = _liveQuotes[quote.symbol];
        return CryptoExploreTile(
          quote: quote,
          livePrice: live?.price,
          liveChangePercent: live?.changePercent,
          onTap: () => openAssetDetail(
            context,
            asset: quote.toAssetItem(),
            fiiRepository: widget.fiiRepository ?? fiiRepository,
            quoteRepository: widget.quoteRepository ?? quoteRepository,
          ),
        );
      },
    );
  }
}

class CryptoExploreTile extends StatelessWidget {
  const CryptoExploreTile({
    super.key,
    required this.quote,
    required this.onTap,
    this.livePrice,
    this.liveChangePercent,
  });

  final CryptoQuoteDto quote;
  final VoidCallback onTap;
  final double? livePrice;
  final double? liveChangePercent;

  @override
  Widget build(BuildContext context) {
    final price = livePrice ?? quote.price;
    final change = liveChangePercent ?? quote.changePercent;
    final changeColor = change >= 0 ? AppColors.positive : AppColors.negative;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AssetCardHeader(
                symbol: quote.symbol,
                name: quote.name,
                logoUrl: quote.imageUrl,
                logoSize: kAssetLogoSizeCompact,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatCryptoPrice(price), style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
