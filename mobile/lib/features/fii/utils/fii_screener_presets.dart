import 'package:rico_investidor/models/fii_models.dart';

class FiiScreenerPreset {
  const FiiScreenerPreset({
    required this.id,
    required this.label,
    required this.params,
  });

  final String id;
  final String label;
  final Map<String, String> params;
}

const fiiScreenerPresets = [
  FiiScreenerPreset(
    id: 'all',
    label: 'Todos',
    params: {'limit': '500'},
  ),
  FiiScreenerPreset(
    id: 'dy_high',
    label: 'Maior DY',
    params: {
      'dividend_yield_ttm_gt': '8',
      'dividend_yield_ttm_lt': '20',
      'sort': 'dividend_yield_ttm',
      'order': 'desc',
      'limit': '50',
    },
  ),
  FiiScreenerPreset(
    id: 'discount',
    label: 'P/VP desconto',
    params: {
      'pvp_lt': '0.95',
      'sort': 'pvp',
      'order': 'asc',
      'limit': '50',
    },
  ),
  FiiScreenerPreset(
    id: 'brick',
    label: 'Tijolo',
    params: {
      'fund_type': 'Tijolo',
      'sort': 'dividend_yield_ttm',
      'order': 'desc',
      'limit': '50',
    },
  ),
  FiiScreenerPreset(
    id: 'paper',
    label: 'Papel',
    params: {
      'fund_type': 'Papel',
      'sort': 'dividend_yield_ttm',
      'order': 'desc',
      'limit': '50',
    },
  ),
  FiiScreenerPreset(
    id: 'logistics',
    label: 'Logística',
    params: {
      'segment': 'Logística',
      'sort': 'dividend_yield_ttm',
      'order': 'desc',
      'limit': '50',
    },
  ),
];

const fiiFeaturedScreenerParams = {
  'dividend_yield_ttm_gt': '7',
  'dividend_yield_ttm_lt': '16',
  'pvp_lt': '1.05',
  'sort': 'dividend_yield_ttm',
  'order': 'desc',
  'limit': '8',
};

/// Fallback quando a API não responde — mantém a seção visível offline.
const featuredFiisOfflineFallback = [
  FiiScreenerItem(
    ticker: 'HGLG11',
    name: 'CSHG Logística',
    closePrice: 162.80,
    dividendYieldTtm: 7.95,
    pvp: 0.93,
  ),
  FiiScreenerItem(
    ticker: 'MXRF11',
    name: 'Maxi Renda',
    closePrice: 10.52,
    dividendYieldTtm: 11.2,
    pvp: 1.01,
  ),
  FiiScreenerItem(
    ticker: 'KNRI11',
    name: 'Kinea Renda Imob.',
    closePrice: 142.30,
    dividendYieldTtm: 8.4,
    pvp: 0.97,
  ),
  FiiScreenerItem(
    ticker: 'XPLG11',
    name: 'XP Log',
    closePrice: 98.50,
    dividendYieldTtm: 9.1,
    pvp: 0.92,
  ),
];
