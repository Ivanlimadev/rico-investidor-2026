import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

abstract final class MockMarketData {
  static const List<AssetItem> featured = [
    AssetItem(
      symbol: 'PETR4',
      name: 'Petrobras PN',
      category: MarketCategory.acoesBr,
      price: 38.42,
      changePercent: 1.24,
    ),
    AssetItem(
      symbol: 'VALE3',
      name: 'Vale ON',
      category: MarketCategory.acoesBr,
      price: 62.15,
      changePercent: -0.58,
    ),
    AssetItem(
      symbol: 'HGLG11',
      name: 'CSHG Logística',
      category: MarketCategory.fiis,
      price: 162.80,
      changePercent: 0.31,
    ),
    AssetItem(
      symbol: 'BTC',
      name: 'Bitcoin',
      category: MarketCategory.cripto,
      price: 542_300,
      changePercent: 2.15,
    ),
    AssetItem(
      symbol: 'IVVB11',
      name: 'iShares S&P 500',
      category: MarketCategory.etfInternacional,
      price: 312.40,
      changePercent: 0.87,
    ),
  ];

  static List<AssetItem> byCategory(MarketCategory category) {
    return allAssets.where((a) => a.category == category).toList();
  }

  static const List<AssetItem> allAssets = [
    ...featured,
    AssetItem(
      symbol: 'ITUB4',
      name: 'Itaú Unibanco PN',
      category: MarketCategory.acoesBr,
      price: 32.18,
      changePercent: 0.42,
    ),
    AssetItem(
      symbol: 'BBAS3',
      name: 'Banco do Brasil ON',
      category: MarketCategory.acoesBr,
      price: 28.90,
      changePercent: -1.12,
    ),
    AssetItem(
      symbol: 'MXRF11',
      name: 'Maxi Renda',
      category: MarketCategory.fiis,
      price: 10.52,
      changePercent: 0.19,
    ),
    AssetItem(
      symbol: 'KNRI11',
      name: 'Kinea Renda Imob.',
      category: MarketCategory.fiis,
      price: 142.30,
      changePercent: -0.22,
    ),
    AssetItem(
      symbol: 'ETH',
      name: 'Ethereum',
      category: MarketCategory.cripto,
      price: 18_450,
      changePercent: 1.88,
    ),
    AssetItem(
      symbol: 'SOL',
      name: 'Solana',
      category: MarketCategory.cripto,
      price: 1_120,
      changePercent: -3.40,
    ),
    AssetItem(
      symbol: 'AAPL34',
      name: 'Apple BDR',
      category: MarketCategory.bdr,
      price: 42.15,
      changePercent: 0.65,
    ),
    AssetItem(
      symbol: 'MSFT34',
      name: 'Microsoft BDR',
      category: MarketCategory.bdr,
      price: 38.70,
      changePercent: 0.12,
    ),
    AssetItem(
      symbol: 'BOVA11',
      name: 'iShares Ibovespa',
      category: MarketCategory.etf,
      price: 128.90,
      changePercent: 0.55,
    ),
    AssetItem(
      symbol: 'SMAL11',
      name: 'iShares Small Cap',
      category: MarketCategory.etf,
      price: 98.40,
      changePercent: 0.22,
    ),
    AssetItem(
      symbol: 'VOO',
      name: 'Vanguard S&P 500',
      category: MarketCategory.etfInternacional,
      price: 512.30,
      changePercent: 0.74,
    ),
    AssetItem(
      symbol: 'QQQ',
      name: 'Invesco QQQ',
      category: MarketCategory.etfInternacional,
      price: 488.10,
      changePercent: 1.05,
    ),
    AssetItem(
      symbol: 'AAPL',
      name: 'Apple Inc.',
      category: MarketCategory.stocks,
      price: 198.50,
      changePercent: 0.91,
    ),
    AssetItem(
      symbol: 'O',
      name: 'Realty Income',
      category: MarketCategory.reits,
      price: 56.20,
      changePercent: -0.34,
    ),
    AssetItem(
      symbol: 'USD/BRL',
      name: 'Dólar comercial',
      category: MarketCategory.moeda,
      price: 5.62,
      changePercent: -0.18,
    ),
    AssetItem(
      symbol: 'EUR/BRL',
      name: 'Euro',
      category: MarketCategory.moeda,
      price: 6.08,
      changePercent: 0.09,
    ),
    AssetItem(
      symbol: 'IBOV',
      name: 'Ibovespa',
      category: MarketCategory.indices,
      price: 128_450,
      changePercent: 0.67,
    ),
    AssetItem(
      symbol: 'IFIX',
      name: 'Índice de FIIs',
      category: MarketCategory.indices,
      price: 3_120,
      changePercent: 0.41,
    ),
    AssetItem(
      symbol: 'SPX',
      name: 'S&P 500',
      category: MarketCategory.indices,
      price: 5_280,
      changePercent: 0.52,
    ),
    AssetItem(
      symbol: 'TESOURO SELIC 2029',
      name: 'Tesouro Selic 2029',
      category: MarketCategory.tesouroDireto,
      price: 14_520.50,
      changePercent: 0.12,
    ),
    AssetItem(
      symbol: 'TESOURO IPCA+ 2035',
      name: 'Tesouro IPCA+ 2035',
      category: MarketCategory.tesouroDireto,
      price: 3_280.80,
      changePercent: 0.08,
    ),
    AssetItem(
      symbol: 'TESOURO PREFIXADO 2028',
      name: 'Tesouro Prefixado 2028',
      category: MarketCategory.tesouroDireto,
      price: 8_910.00,
      changePercent: -0.05,
    ),
  ];
}
