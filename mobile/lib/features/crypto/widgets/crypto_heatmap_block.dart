import 'package:flutter/material.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_heatmap_card.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Carrega e exibe o mapa de calor de cripto (top volume USDT · 24h).
class CryptoHeatmapBlock extends StatefulWidget {
  const CryptoHeatmapBlock({
    super.key,
    required this.onTap,
    this.liveChanges = const {},
    this.onSymbolsLoaded,
    this.repository,
  });

  final ValueChanged<AssetItem> onTap;
  final Map<String, double> liveChanges;
  final void Function(Set<String> symbols)? onSymbolsLoaded;
  final CryptoRepository? repository;

  @override
  State<CryptoHeatmapBlock> createState() => _CryptoHeatmapBlockState();
}

class _CryptoHeatmapBlockState extends State<CryptoHeatmapBlock> {
  late Future<CryptoListResponseDto?> _future;

  CryptoRepository get _repository => widget.repository ?? cryptoRepository;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CryptoListResponseDto?> _load() async {
    try {
      await authSession.ensureAuthenticated();
      final heatmap = await _repository.getHeatmap();
      precacheCryptoLogos(heatmap.items.map((quote) => quote.symbol));
      widget.onSymbolsLoaded?.call(heatmap.items.map((quote) => quote.symbol).toSet());
      return heatmap;
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CryptoListResponseDto?>(
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

        return CryptoHeatmapSection(
          items: heatmap.items,
          liveChanges: widget.liveChanges,
          onTap: widget.onTap,
        );
      },
    );
  }
}
