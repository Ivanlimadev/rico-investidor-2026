import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/models/fii_models.dart';

const relatedFiisLimit = 6;

int scoreRelatedFii(FiiScreenerItem item, FiiDetail detail) {
  var score = 0;

  if (detail.segment != null &&
      item.segment != null &&
      _norm(detail.segment!) == _norm(item.segment!)) {
    score += 4;
  }

  if (detail.fundType != null &&
      item.fundType != null &&
      _norm(detail.fundType!) == _norm(item.fundType!)) {
    score += 3;
  }

  if (detail.administrator != null &&
      item.administratorName != null &&
      _norm(detail.administrator!) == _norm(item.administratorName!)) {
    score += 3;
  }

  if (detail.managementType != null &&
      item.managementType != null &&
      _norm(detail.managementType!) == _norm(item.managementType!)) {
    score += 1;
  }

  return score;
}

String relatedFiiReason(FiiScreenerItem item, FiiDetail detail) {
  final parts = <String>[];

  if (detail.segment != null &&
      item.segment != null &&
      _norm(detail.segment!) == _norm(item.segment!)) {
    parts.add(item.segment!);
  }

  if (detail.fundType != null &&
      item.fundType != null &&
      _norm(detail.fundType!) == _norm(item.fundType!)) {
    parts.add(item.fundType!);
  }

  if (parts.isEmpty &&
      detail.administrator != null &&
      item.administratorName != null &&
      _norm(detail.administrator!) == _norm(item.administratorName!)) {
    return 'Mesmo administrador';
  }

  if (parts.isEmpty && detail.managementType != null) {
    return detail.managementType!;
  }

  return parts.take(2).join(' · ');
}

String relatedFiisSubtitle(FiiDetail detail) {
  final parts = <String>[];
  if (detail.segment != null) parts.add(detail.segment!);
  if (detail.fundType != null) parts.add(detail.fundType!);
  if (parts.isEmpty && detail.administrator != null) {
    return 'Mesmo perfil de ${detail.administrator}';
  }
  if (parts.isEmpty) return 'Explore outros fundos similares';
  return 'Mesmo perfil: ${parts.join(' · ')}';
}

List<FiiScreenerItem> pickRelatedFiis({
  required FiiDetail detail,
  required Iterable<FiiScreenerItem> candidates,
  int limit = relatedFiisLimit,
}) {
  final current = normalizeFiiTicker(detail.ticker);
  final scored = candidates
      .where((item) => normalizeFiiTicker(item.ticker) != current)
      .map((item) => (item: item, score: scoreRelatedFii(item, detail)))
      .where((e) => e.score > 0)
      .toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return (b.item.dividendYieldTtm ?? 0).compareTo(a.item.dividendYieldTtm ?? 0);
    });

  final seen = <String>{};
  final result = <FiiScreenerItem>[];
  for (final entry in scored) {
    if (seen.add(entry.item.ticker)) {
      result.add(entry.item);
      if (result.length >= limit) break;
    }
  }
  return result;
}

String _norm(String value) => value.trim().toLowerCase();
