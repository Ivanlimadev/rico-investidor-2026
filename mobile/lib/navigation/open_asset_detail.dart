import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/markets/market_visibility.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/core/search/asset_search_ranking.dart';
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
  SubscriptionPlan? plan,
}) {
  openTickerDetail(
    context,
    ticker: asset.symbol,
    globalMarketRepo: globalMarketRepository,
    category: asset.category,
    exchangeMic: asset.exchangeMic,
    plan: plan,
  );
}

/// Abre detalhe do ativo — ações US, REITs ou cripto.
SubscriptionPlan _resolveSubscriptionPlan(BuildContext context, SubscriptionPlan? plan) {
  if (plan != null) return plan;
  return AppShellScope.maybeOf(context)?.subscriptionPlan ?? SubscriptionPlan.free;
}

void openTickerDetail(
  BuildContext context, {
  required String ticker,
  GlobalMarketRepository? globalMarketRepo,
  MarketCategory? category,
  String? exchangeMic,
  SubscriptionPlan? plan,
}) {
  final trimmed = ticker.trim();
  final normalized = trimmed.toUpperCase();
  final resolvedGlobalRepo = globalMarketRepo ?? globalMarketRepository;
  final resolvedCategory = resolveMarketCategory(
    symbol: normalized,
    stored: category,
  );
  final resolvedPlan = _resolveSubscriptionPlan(context, plan);

  if (resolvedCategory == MarketCategory.cripto || looksLikeObviousCryptoTicker(normalized)) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CryptoDetailScreen(
          symbol: normalizeCryptoSymbol(trimmed),
          plan: resolvedPlan,
        ),
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
        plan: resolvedPlan,
      ),
    ),
  );
}

void openTickerDetailQuick(BuildContext context, String ticker) {
  openTickerDetail(context, ticker: ticker);
}
