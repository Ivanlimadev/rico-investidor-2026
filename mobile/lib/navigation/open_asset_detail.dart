import 'package:flutter/material.dart';
import 'package:rico_investidor/core/markets/market_visibility.dart';
import 'package:rico_investidor/core/search/asset_search_ranking.dart';
import 'package:rico_investidor/core/utils/crypto_ticker_utils.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/screens/crypto_detail_screen.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_detail_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

void openAssetDetail(
  BuildContext context, {
  required AssetItem asset,
  GlobalMarketRepository? globalMarketRepository,
}) {
  openTickerDetail(
    context,
    ticker: asset.symbol,
    globalMarketRepo: globalMarketRepository,
    category: asset.category,
    exchangeMic: asset.exchangeMic,
  );
}

/// Abre detalhe do ativo — ações US, REITs ou cripto.
void openTickerDetail(
  BuildContext context, {
  required String ticker,
  GlobalMarketRepository? globalMarketRepo,
  MarketCategory? category,
  String? exchangeMic,
}) {
  final trimmed = ticker.trim();
  final normalized = trimmed.toUpperCase();
  final resolvedGlobalRepo = globalMarketRepo ?? globalMarketRepository;
  final resolvedCategory = resolveMarketCategory(
    symbol: normalized,
    stored: category,
  );

  if (resolvedCategory == MarketCategory.cripto || looksLikeObviousCryptoTicker(normalized)) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CryptoDetailScreen(symbol: normalizeCryptoSymbol(trimmed)),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GlobalStockDetailScreen(
        symbol: normalized,
        repository: resolvedGlobalRepo,
        exchange: exchangeMic,
      ),
    ),
  );
}

void openTickerDetailQuick(BuildContext context, String ticker) {
  openTickerDetail(context, ticker: ticker);
}
