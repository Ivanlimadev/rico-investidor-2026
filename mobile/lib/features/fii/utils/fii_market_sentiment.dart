import 'package:rico_investidor/features/fii/utils/fii_returns.dart';
import 'package:rico_investidor/models/fii_models.dart';

enum FiiSentimentLevel {
  veryBullish,
  bullish,
  neutral,
  bearish,
  veryBearish,
}

class FiiSentimentPeriod {
  const FiiSentimentPeriod({
    required this.label,
    required this.priceReturnPct,
  });

  final String label;
  final double priceReturnPct;
}

class FiiMarketSentiment {
  const FiiMarketSentiment({
    required this.level,
    required this.label,
    required this.score,
    required this.summary,
    required this.periods,
    required this.positivePeriods,
    required this.negativePeriods,
  });

  final FiiSentimentLevel level;
  final String label;
  final double score;
  final String summary;
  final List<FiiSentimentPeriod> periods;
  final int positivePeriods;
  final int negativePeriods;
}

const _sentimentWeights = {
  '1M': 0.30,
  '3M': 0.25,
  '1A': 0.25,
  '3A': 0.12,
  '5A': 0.08,
};

FiiMarketSentiment? computeFiiMarketSentiment({
  required List<FiiHistoryPoint> history,
  required double? currentPrice,
  List<FiiCandleBar> candles = const [],
}) {
  if ((history.isEmpty && candles.isEmpty) || currentPrice == null || currentPrice <= 0) {
    return null;
  }

  final returns = computeFiiReturns(
    history: history,
    currentPrice: currentPrice,
    candles: candles,
  );

  final byLabel = {for (final item in returns) item.label: item};

  var weightedScore = 0.0;
  var usedWeight = 0.0;
  final periods = <FiiSentimentPeriod>[];
  var positive = 0;
  var negative = 0;

  for (final entry in _sentimentWeights.entries) {
    final item = byLabel[entry.key];
    final pricePct = item?.priceReturnPct;
    if (pricePct == null) continue;

    final normalized = (pricePct / 20).clamp(-1.0, 1.0);
    weightedScore += normalized * entry.value;
    usedWeight += entry.value;

    periods.add(FiiSentimentPeriod(label: entry.key, priceReturnPct: pricePct));
    if (pricePct >= 0) {
      positive++;
    } else {
      negative++;
    }
  }

  if (periods.isEmpty) return null;

  final score = usedWeight == 0 ? 0.0 : (weightedScore / usedWeight) * 100;
  final level = _levelForScore(score);

  return FiiMarketSentiment(
    level: level,
    label: _labelForLevel(level),
    score: score,
    summary: _buildSummary(level, periods),
    periods: periods,
    positivePeriods: positive,
    negativePeriods: negative,
  );
}

FiiSentimentLevel _levelForScore(double score) {
  if (score >= 50) return FiiSentimentLevel.veryBullish;
  if (score >= 20) return FiiSentimentLevel.bullish;
  if (score >= -20) return FiiSentimentLevel.neutral;
  if (score >= -50) return FiiSentimentLevel.bearish;
  return FiiSentimentLevel.veryBearish;
}

String _labelForLevel(FiiSentimentLevel level) {
  return switch (level) {
    FiiSentimentLevel.veryBullish => 'Muito otimista',
    FiiSentimentLevel.bullish => 'Otimista',
    FiiSentimentLevel.neutral => 'Neutro',
    FiiSentimentLevel.bearish => 'Pessimista',
    FiiSentimentLevel.veryBearish => 'Muito pessimista',
  };
}

String _buildSummary(FiiSentimentLevel level, List<FiiSentimentPeriod> periods) {
  final short = periods.where((p) => p.label == '1M' || p.label == '3M').toList();
  final long = periods.where((p) => p.label == '3A' || p.label == '5A').toList();

  final shortUp = short.where((p) => p.priceReturnPct >= 0).length;
  final shortDown = short.length - shortUp;
  final longUp = long.where((p) => p.priceReturnPct >= 0).length;
  final longDown = long.length - longUp;

  if (level == FiiSentimentLevel.veryBullish || level == FiiSentimentLevel.bullish) {
    if (shortUp == short.length && long.isNotEmpty && longUp == long.length) {
      return 'Valorização da cotação no curto e no longo prazo.';
    }
    if (shortUp >= shortDown) {
      return 'Mercado comprador — cotação em alta nos prazos recentes.';
    }
    return 'Recuperação no longo prazo apesar de fraqueza recente.';
  }

  if (level == FiiSentimentLevel.veryBearish || level == FiiSentimentLevel.bearish) {
    if (shortDown == short.length && long.isNotEmpty && longDown == long.length) {
      return 'Desvalorização consistente — pressão vendedora nos prazos analisados.';
    }
    if (shortDown >= shortUp) {
      return 'Mercado cauteloso — cotação cede nos prazos recentes.';
    }
    return 'Fraqueza no longo prazo, com alguma estabilidade recente.';
  }

  return 'Sinais mistos entre valorização e desvalorização da cotação.';
}
