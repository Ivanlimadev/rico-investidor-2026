import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/heatmap_layout.dart';

export 'package:rico_investidor/core/widgets/market_heatmap/heatmap_layout.dart';

List<List<CryptoQuoteDto>> partitionCryptoHeatmapRows(List<CryptoQuoteDto> items) {
  final generic = items
      .map(
        (quote) => HeatmapTileItem(
          symbol: quote.symbol,
          changePercent: quote.changePercent,
          volume: quote.volume,
        ),
      )
      .toList();
  final rows = partitionHeatmapRows(generic);
  var offset = 0;
  final result = <List<CryptoQuoteDto>>[];
  for (final row in rows) {
    result.add(items.sublist(offset, offset + row.length));
    offset += row.length;
  }
  return result;
}

double cryptoHeatmapTileVolume(CryptoQuoteDto quote) {
  return heatmapTileVolume(
    HeatmapTileItem(
      symbol: quote.symbol,
      changePercent: quote.changePercent,
      volume: quote.volume,
    ),
  );
}
