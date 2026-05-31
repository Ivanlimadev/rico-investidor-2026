import 'package:rico_investidor/models/market_category.dart';

/// Ativos e mercados negociados ou referenciados na Bolsa brasileira (B3).
const brazilianMarketCategories = <MarketCategory>[
  MarketCategory.acoesBr,
  MarketCategory.fiis,
  MarketCategory.bdr,
  MarketCategory.etf,
  MarketCategory.moeda,
  MarketCategory.indices,
  MarketCategory.tesouroDireto,
];

/// Demais mercados exibidos fora dos hubs EUA e Brasil.
const globalMarketCategories = <MarketCategory>[
  MarketCategory.cripto,
  MarketCategory.etfInternacional,
];

bool isBrazilianMarketCategory(MarketCategory category) {
  return brazilianMarketCategories.contains(category);
}
