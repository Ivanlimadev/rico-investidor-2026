class CryptoExploreGroup {
  const CryptoExploreGroup({required this.id, required this.label});

  final String id;
  final String label;
}

const cryptoExploreGroups = [
  CryptoExploreGroup(id: 'major', label: 'Principais'),
  CryptoExploreGroup(id: 'defi', label: 'DeFi'),
  CryptoExploreGroup(id: 'meme', label: 'Meme'),
  CryptoExploreGroup(id: 'all', label: 'Todos'),
];
