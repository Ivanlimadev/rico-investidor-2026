import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/features/crypto/data/crypto_mini_ticker_stream.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class CryptoLiveMarketList extends StatefulWidget {
  const CryptoLiveMarketList({
    super.key,
    required this.assets,
    required this.fiiRepository,
    required this.quoteRepository,
  });

  final List<AssetItem> assets;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  @override
  State<CryptoLiveMarketList> createState() => _CryptoLiveMarketListState();
}

class _CryptoLiveMarketListState extends State<CryptoLiveMarketList> {
  final _livePrices = <String, CryptoLiveQuote>{};
  CryptoMiniTickerStream? _stream;

  @override
  void initState() {
    super.initState();
    _stream = CryptoMiniTickerStream(
      onQuote: (quote) {
        if (!mounted) return;
        setState(() => _livePrices[quote.symbol] = quote);
      },
    )..connect(widget.assets.map((asset) => asset.symbol));
  }

  @override
  void dispose() {
    _stream?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: widget.assets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final asset = widget.assets[index];
        final live = _livePrices[asset.symbol];
        final price = live?.price ?? asset.price;
        final change = live?.changePercent ?? asset.changePercent;
        final changeColor = change >= 0 ? AppColors.positive : AppColors.negative;

        return Card(
          child: ListTile(
            onTap: () => openAssetDetail(
              context,
              asset: asset,
              fiiRepository: widget.fiiRepository,
              quoteRepository: widget.quoteRepository,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: AssetListLeading(symbol: asset.symbol, logoUrl: asset.logoUrl),
            title: Text(asset.symbol, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(asset.name),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
        );
      },
    );
  }
}
