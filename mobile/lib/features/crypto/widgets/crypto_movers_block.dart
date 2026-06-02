import 'package:flutter/material.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_movers_cards.dart';
import 'package:rico_investidor/models/asset_item.dart';

class CryptoMoversBlock extends StatefulWidget {
  const CryptoMoversBlock({
    super.key,
    required this.onTap,
    this.repository,
  });

  final ValueChanged<AssetItem> onTap;
  final CryptoRepository? repository;

  @override
  State<CryptoMoversBlock> createState() => _CryptoMoversBlockState();
}

class _CryptoMoversBlockState extends State<CryptoMoversBlock> {
  late Future<CryptoMoversResponseDto?> _future;

  CryptoRepository get _repository => widget.repository ?? cryptoRepository;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CryptoMoversResponseDto?> _load() async {
    try {
      await authSession.ensureAuthenticated();
      return await _repository.getMovers();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CryptoMoversResponseDto?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final movers = snapshot.data;
        if (movers == null) return const SizedBox.shrink();

        return CryptoMoversSection(movers: movers, onTap: widget.onTap);
      },
    );
  }
}
