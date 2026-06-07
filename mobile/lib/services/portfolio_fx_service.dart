import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';

/// Cotação USD/BRL (quantos reais por 1 dólar) para converter a carteira para US$.
class PortfolioFxService {
  PortfolioFxService({CryptoRepository? repository})
      : _cryptoRepository = repository ?? cryptoRepository;

  final CryptoRepository _cryptoRepository;

  Future<double?> fetchUsdBrlRate() async {
    try {
      final macro = await _cryptoRepository.getMacro();
      final rate = macro.usdtBrlRate;
      if (rate != null && rate > 0) return rate;
    } catch (_) {}
    try {
      final profile = await _cryptoRepository.getProfile('BTC');
      final rate = profile.brl.usdtBrlRate;
      if (rate != null && rate > 0) return rate;
    } catch (_) {}
    return null;
  }
}

final portfolioFxService = PortfolioFxService();
