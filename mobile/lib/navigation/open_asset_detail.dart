import 'package:flutter/material.dart';
import 'package:rico_investidor/features/assets/screens/asset_detail_screen.dart';
import 'package:rico_investidor/features/crypto/screens/crypto_detail_screen.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_detail_screen.dart';
import 'package:rico_investidor/features/currency/screens/currency_detail_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/screens/stock_detail_screen.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';
import 'package:rico_investidor/features/indices/screens/index_detail_screen.dart';
import 'package:rico_investidor/features/treasury/models/treasury_models.dart';
import 'package:rico_investidor/features/treasury/screens/treasury_detail_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

void openAssetDetail(
  BuildContext context, {
  required AssetItem asset,
  required FiiRepository fiiRepository,
  required QuoteRepository quoteRepository,
  GlobalMarketRepository? globalMarketRepository,
}) {
  openTickerDetail(
    context,
    ticker: asset.symbol,
    fiiRepo: fiiRepository,
    quoteRepo: quoteRepository,
    globalMarketRepo: globalMarketRepository,
    category: asset.category,
    exchangeMic: asset.exchangeMic,
  );
}

/// Abre detalhe do ativo — FII ou ação — sem passar pelo loader unificado.
void openTickerDetail(
  BuildContext context, {
  required String ticker,
  FiiRepository? fiiRepo,
  QuoteRepository? quoteRepo,
  GlobalMarketRepository? globalMarketRepo,
  MarketCategory? category,
  String? exchangeMic,
}) {
  final trimmed = ticker.trim();
  final normalized = trimmed.toUpperCase();
  final resolvedFiiRepo = fiiRepo ?? fiiRepository;
  final resolvedQuoteRepo = quoteRepo ?? quoteRepository;
  final resolvedGlobalRepo = globalMarketRepo ?? globalMarketRepository;

  if (category == MarketCategory.tesouroDireto || trimmed.toLowerCase().startsWith('tesouro-')) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TreasuryDetailScreen(symbol: normalizeTreasurySymbol(trimmed)),
      ),
    );
    return;
  }

  if (category == MarketCategory.indices || (category == null && _looksLikeIndex(trimmed))) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IndexDetailScreen(symbol: normalizeIndexSymbol(trimmed)),
      ),
    );
    return;
  }

  if (category == MarketCategory.stocks || category == MarketCategory.reits) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GlobalStockDetailScreen(
          symbol: normalized,
          repository: resolvedGlobalRepo,
          exchange: exchangeMic,
        ),
      ),
    );
    return;
  }

  if (category == MarketCategory.cripto || (category == null && _looksLikeCrypto(trimmed))) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CryptoDetailScreen(symbol: normalizeCryptoSymbol(trimmed)),
      ),
    );
    return;
  }

  if (category == MarketCategory.moeda || normalized.contains('-BRL')) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CurrencyDetailScreen(pair: normalized),
      ),
    );
    return;
  }

  if (_isBrListedAsset(normalized, category)) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssetDetailScreen(
          ticker: normalized,
          fiiRepository: resolvedFiiRepo,
          quoteRepository: resolvedQuoteRepo,
        ),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StockDetailScreen(
        ticker: normalized,
        category: category ?? _inferStockCategory(normalized),
        repository: resolvedQuoteRepo,
      ),
    ),
  );
}

bool _isBrListedAsset(String ticker, MarketCategory? category) {
  if (category == MarketCategory.acoesBr ||
      category == MarketCategory.bdr ||
      category == MarketCategory.etf ||
      category == MarketCategory.fiis) {
    return true;
  }
  if (category != null) return false;
  if (isFiiTicker(ticker)) return true;
  final inferred = _inferStockCategory(ticker);
  return inferred == MarketCategory.acoesBr || inferred == MarketCategory.bdr;
}

MarketCategory _inferStockCategory(String symbol) {
  if (symbol.length >= 2) {
    final suffix = symbol.substring(symbol.length - 2);
    if (suffix == '34' || suffix == '35' || suffix == '39') {
      return MarketCategory.bdr;
    }
  }
  return MarketCategory.acoesBr;
}

bool _looksLikeIndex(String symbol) {
  final normalized = normalizeIndexSymbol(symbol);
  return normalized.startsWith('^') ||
      {
        'IFIX',
        'IDIV',
        'SMLL',
        'IFNC',
        'IMAT',
        'INDX',
        'IMOB',
        'ICON',
        'IEE',
        'UTIL',
      }.contains(normalized);
}

bool _looksLikeCrypto(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.contains('-') || normalized.contains('/')) return false;
  if (normalized.length < 2 || normalized.length > 12) return false;
  if (RegExp(r'\d$').hasMatch(normalized) && normalized.length >= 5) return false;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(normalized);
}

/// Atalho com repositórios globais (telas que só têm FiiRepository).
void openTickerDetailQuick(BuildContext context, String ticker) {
  openTickerDetail(context, ticker: ticker);
}
