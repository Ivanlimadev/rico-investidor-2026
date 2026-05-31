import 'package:rico_investidor/features/currency/data/currency_repository.dart';

/// Cotação USD/BRL (quantos reais por 1 dólar) para converter a carteira para US$.
class PortfolioFxService {
  PortfolioFxService({CurrencyRepository? repository})
      : _currencyRepository = repository ?? currencyRepository;

  final CurrencyRepository _currencyRepository;

  Future<double?> fetchUsdBrlRate() async {
    try {
      final detail = await _currencyRepository.getDetail('USD-BRL');
      return detail.quote.midPrice;
    } catch (_) {
      return null;
    }
  }
}

final portfolioFxService = PortfolioFxService();
