class CurrencyExploreGroup {
  const CurrencyExploreGroup({required this.id, required this.label});

  final String id;
  final String label;
}

const currencyExploreGroups = [
  CurrencyExploreGroup(id: 'all', label: 'Todos'),
  CurrencyExploreGroup(id: 'majors', label: 'Principais'),
  CurrencyExploreGroup(id: 'americas', label: 'Américas'),
  CurrencyExploreGroup(id: 'europe', label: 'Europa'),
  CurrencyExploreGroup(id: 'asia', label: 'Ásia'),
];
