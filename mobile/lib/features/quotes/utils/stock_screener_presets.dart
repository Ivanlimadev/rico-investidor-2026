class StockScreenerPreset {
  const StockScreenerPreset({
    required this.id,
    required this.label,
    this.sector,
    this.sortBy = 'volume',
    this.sortOrder = 'desc',
    this.type = 'stock',
    this.minDividendYield,
    this.maxDividendYield,
    this.minPriceEarnings,
    this.maxPriceEarnings,
    this.minReturnOnEquity,
    this.maxReturnOnEquity,
    this.minPriceToBook,
    this.maxPriceToBook,
  });

  final String id;
  final String label;
  final String? sector;
  final String sortBy;
  final String sortOrder;
  final String type;
  final double? minDividendYield;
  final double? maxDividendYield;
  final double? minPriceEarnings;
  final double? maxPriceEarnings;
  final double? minReturnOnEquity;
  final double? maxReturnOnEquity;
  final double? minPriceToBook;
  final double? maxPriceToBook;

  Map<String, String> toQuery({int limit = 50}) {
    final query = <String, String>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'type': type,
      'limit': '$limit',
    };
    if (sector != null) query['sector'] = sector!;
    void addDouble(String key, double? value) {
      if (value != null) query[key] = '$value';
    }

    addDouble('min_dividend_yield', minDividendYield);
    addDouble('max_dividend_yield', maxDividendYield);
    addDouble('min_price_earnings', minPriceEarnings);
    addDouble('max_price_earnings', maxPriceEarnings);
    addDouble('min_return_on_equity', minReturnOnEquity);
    addDouble('max_return_on_equity', maxReturnOnEquity);
    addDouble('min_price_to_book', minPriceToBook);
    addDouble('max_price_to_book', maxPriceToBook);
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
    id: 'dy_high',
    label: 'DY alto',
    sortBy: 'dividend_yield',
    sortOrder: 'desc',
    minDividendYield: 6,
  ),
  StockScreenerPreset(
    id: 'low_pe',
    label: 'P/L baixo',
    sortBy: 'price_earnings',
    sortOrder: 'asc',
    maxPriceEarnings: 10,
  ),
  StockScreenerPreset(
    id: 'high_roe',
    label: 'ROE alto',
    sortBy: 'return_on_equity',
    sortOrder: 'desc',
    minReturnOnEquity: 15,
  ),
  StockScreenerPreset(
    id: 'low_pvp',
    label: 'P/VP < 1,5',
    sortBy: 'price_to_book',
    sortOrder: 'asc',
    maxPriceToBook: 1.5,
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
