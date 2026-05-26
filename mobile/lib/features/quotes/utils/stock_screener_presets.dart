class StockScreenerPreset {
  const StockScreenerPreset({
    required this.id,
    required this.label,
    this.sector,
    this.sortBy = 'volume',
    this.sortOrder = 'desc',
    this.type = 'stock',
  });

  final String id;
  final String label;
  final String? sector;
  final String sortBy;
  final String sortOrder;
  final String type;

  Map<String, String> toQuery({int limit = 50}) {
    final query = <String, String>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'type': type,
      'limit': '$limit',
    };
    if (sector != null) query['sector'] = sector!;
    return query;
  }
}

const stockScreenerPresets = [
  StockScreenerPreset(
    id: 'volume',
    label: 'Mais negociadas',
    sortBy: 'volume',
  ),
  StockScreenerPreset(
    id: 'gainers',
    label: 'Maiores altas',
    sortBy: 'change',
    sortOrder: 'desc',
  ),
  StockScreenerPreset(
    id: 'losers',
    label: 'Maiores quedas',
    sortBy: 'change',
    sortOrder: 'asc',
  ),
  StockScreenerPreset(
    id: 'market_cap',
    label: 'Maior cap.',
    sortBy: 'market_cap',
  ),
  StockScreenerPreset(
    id: 'finance',
    label: 'Financeiro',
    sector: 'Finance',
    sortBy: 'volume',
  ),
  StockScreenerPreset(
    id: 'energy',
    label: 'Energia',
    sector: 'Energy Minerals',
    sortBy: 'volume',
  ),
  StockScreenerPreset(
    id: 'utilities',
    label: 'Utilidades',
    sector: 'Utilities',
    sortBy: 'volume',
  ),
  StockScreenerPreset(
    id: 'retail',
    label: 'Varejo',
    sector: 'Retail Trade',
    sortBy: 'volume',
  ),
];

const bdrScreenerPresets = [
  StockScreenerPreset(
    id: 'volume',
    label: 'Mais negociadas',
    sortBy: 'volume',
    type: 'bdr',
  ),
  StockScreenerPreset(
    id: 'gainers',
    label: 'Maiores altas',
    sortBy: 'change',
    sortOrder: 'desc',
    type: 'bdr',
  ),
  StockScreenerPreset(
    id: 'losers',
    label: 'Maiores quedas',
    sortBy: 'change',
    sortOrder: 'asc',
    type: 'bdr',
  ),
];

List<StockScreenerPreset> presetsForCategory(String categorySlug) {
  return switch (categorySlug) {
    'bdr' => bdrScreenerPresets,
    _ => stockScreenerPresets,
  };
}

String sectorLabel(String? sector) {
  if (sector == null || sector.isEmpty) return '—';
  return switch (sector) {
    'Finance' => 'Financeiro',
    'Energy Minerals' => 'Energia',
    'Utilities' => 'Utilidades',
    'Retail Trade' => 'Varejo',
    'Health Services' => 'Saúde',
    'Technology Services' => 'Tecnologia',
    'Consumer Services' => 'Consumo',
    'Producer Manufacturing' => 'Indústria',
    'Transportation' => 'Transporte',
    'Communications' => 'Comunicações',
    _ => sector,
  };
}
