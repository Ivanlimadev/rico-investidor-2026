import 'package:flutter/material.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/heatmap_layout.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/market_heatmap_section.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/models/asset_item.dart';

typedef HeatmapLoader = Future<QuoteListResponse?> Function();

/// Carrega e exibe mapa de calor de ações (BR ou EUA).
///
/// Passe [reloadKey] distinto por mercado (ex.: `BR` vs `US`) para forçar
/// recarga ao trocar o mercado preferido — o Flutter reutiliza [State] entre
/// instâncias consecutivas do mesmo widget na mesma posição da árvore.
class StockHeatmapBlock extends StatefulWidget {
  const StockHeatmapBlock({
    super.key,
    required this.load,
    required this.onTap,
    required this.volumeLabel,
    this.title = 'Mapa de calor · 24h',
    this.mapAsset,
    this.reloadKey,
  });

  final HeatmapLoader load;
  final ValueChanged<AssetItem> onTap;
  final String volumeLabel;
  final String title;
  final AssetItem Function(MarketQuoteDto quote)? mapAsset;

  /// Identificador do mercado/fonte — muda → recarrega dados.
  final String? reloadKey;

  @override
  State<StockHeatmapBlock> createState() => _StockHeatmapBlockState();
}

class _StockHeatmapBlockState extends State<StockHeatmapBlock> {
  late Future<QuoteListResponse?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant StockHeatmapBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey ||
        oldWidget.volumeLabel != widget.volumeLabel) {
      setState(() => _future = _load());
    }
  }

  Future<QuoteListResponse?> _load() async {
    try {
      await authSession.ensureAuthenticated();
      final response = await widget.load();
      if (response == null || response.items.isEmpty) return null;
      return response;
    } catch (error) {
      debugPrint('StockHeatmapBlock: $error');
      rethrow;
    }
  }

  void _retry() {
    setState(() => _future = _load());
  }

  List<HeatmapEntry> _entries(QuoteListResponse response) {
    return response.items.map((quote) {
      final asset = widget.mapAsset?.call(quote) ?? quote.toAssetItem();
      return HeatmapEntry(
        item: HeatmapTileItem(
          symbol: quote.symbol,
          changePercent: quote.changePercent,
          volume: quote.volume,
        ),
        asset: asset,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuoteListResponse?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Mapa de calor indisponível',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final heatmap = snapshot.data;
        if (heatmap == null || heatmap.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Recarregar mapa de calor'),
            ),
          );
        }

        return MarketHeatmapSection(
          entries: _entries(heatmap),
          onTap: widget.onTap,
          volumeLabel: widget.volumeLabel,
          title: widget.title,
        );
      },
    );
  }
}
