import 'package:flutter/material.dart';
import 'package:rico_investidor/features/assets/screens/asset_detail_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';

void openAssetDetail(
  BuildContext context, {
  required AssetItem asset,
  required FiiRepository fiiRepository,
  required QuoteRepository quoteRepository,
}) {
  openTickerDetail(
    context,
    ticker: asset.symbol,
    fiiRepo: fiiRepository,
    quoteRepo: quoteRepository,
  );
}

/// Abre detalhe via `/v1/assets/{ticker}` — roteia FII vs ação no backend.
void openTickerDetail(
  BuildContext context, {
  required String ticker,
  FiiRepository? fiiRepo,
  QuoteRepository? quoteRepo,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AssetDetailScreen(
        ticker: ticker,
        fiiRepository: fiiRepo ?? fiiRepository,
        quoteRepository: quoteRepo ?? quoteRepository,
      ),
    ),
  );
}

/// Atalho com repositórios globais (telas que só têm FiiRepository).
void openTickerDetailQuick(BuildContext context, String ticker) {
  openTickerDetail(context, ticker: ticker);
}
