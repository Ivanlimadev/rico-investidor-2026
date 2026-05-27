import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/features/crypto/data/crypto_price_stream.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_chart_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_live_order_book_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_trades_card.dart';

class CryptoDetailScreen extends StatefulWidget {
  const CryptoDetailScreen({
    super.key,
    required this.symbol,
    this.repository,
  });

  final String symbol;
  final CryptoRepository? repository;

  @override
  State<CryptoDetailScreen> createState() => _CryptoDetailScreenState();
}

class _CryptoDetailScreenState extends State<CryptoDetailScreen> {
  late Future<CryptoDetailDto> _loadFuture;
  CryptoPriceStream? _priceStream;
  double? _livePrice;
  bool _streamLive = false;

  CryptoRepository get _repository => widget.repository ?? cryptoRepository;

  @override
  void initState() {
    super.initState();
    _loadFuture = _repository.getDetail(widget.symbol).then((detail) {
      _startLivePrice(detail.quote.symbol);
      return detail;
    });
  }

  @override
  void dispose() {
    _priceStream?.close();
    super.dispose();
  }

  void _startLivePrice(String symbol) {
    _priceStream?.close();
    _priceStream = CryptoPriceStream(
      symbol: symbol,
      onTrade: (trade) {
        if (!mounted) return;
        setState(() {
          _livePrice = trade.price;
          _streamLive = true;
        });
      },
    )..connect();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeCryptoSymbol(widget.symbol);

    return Scaffold(
      appBar: AppBar(
        title: Text(normalized),
        actions: const [ShellHomeButton()],
      ),
      body: FutureBuilder<CryptoDetailDto>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar $normalized.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final quote = detail.quote;
          final market = detail.market;
          final displayPrice = _livePrice ?? quote.price;
          final change = quote.changePercent;
          final isPositive = change >= 0;
          final changeColor = isPositive ? AppColors.positive : AppColors.negative;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AssetCardHeader(
                symbol: quote.symbol,
                name: quote.name,
                logoUrl: quote.imageUrl,
                trailing: Text(
                  formatCryptoPrice(displayPrice, currency: quote.currency),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}% em 24h',
                    style: TextStyle(color: changeColor, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (_streamLive) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.positive, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ao vivo',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.positive,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
              if (quote.bidPrice != null && quote.askPrice != null) ...[
                const SizedBox(height: 12),
                _BidAskRow(quote: quote),
              ],
              const SizedBox(height: 16),
              CryptoChartCard(
                symbol: quote.symbol,
                repository: _repository,
                initialCandles: detail.candles,
              ),
              if (market != null) ...[
                const SizedBox(height: 16),
                CryptoLiveOrderBookCard(
                  symbol: quote.symbol,
                  initialBook: market.orderBook,
                ),
                const SizedBox(height: 16),
                CryptoRecentTradesCard(trades: market.trades),
              ],
              const SizedBox(height: 12),
              Text(
                'Par ${quote.symbol}/USDT · USD · Binance REST + WebSocket público.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BidAskRow extends StatelessWidget {
  const _BidAskRow({required this.quote});

  final CryptoQuoteDto quote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Book ticker', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Bid',
                    value: formatCryptoPrice(quote.bidPrice!, currency: quote.currency),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Ask',
                    value: formatCryptoPrice(quote.askPrice!, currency: quote.currency),
                  ),
                ),
              ],
            ),
            if (quote.spread != null) ...[
              const SizedBox(height: 12),
              _StatTile(
                label: 'Spread',
                value: '${formatCryptoPrice(quote.spread!, currency: quote.currency)}'
                    '${quote.spreadPercent != null ? ' (${quote.spreadPercent!.toStringAsFixed(3)}%)' : ''}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
