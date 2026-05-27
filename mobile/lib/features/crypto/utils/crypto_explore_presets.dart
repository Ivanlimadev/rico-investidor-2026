class CryptoExploreGroup {
  const CryptoExploreGroup({required this.id, required this.label});

  final String id;
  final String label;
}

const cryptoExploreGroups = [
  CryptoExploreGroup(id: 'all', label: 'Todos'),
  CryptoExploreGroup(id: 'major', label: 'Principais'),
  CryptoExploreGroup(id: 'layer1', label: 'Layer 1'),
  CryptoExploreGroup(id: 'defi', label: 'DeFi'),
  CryptoExploreGroup(id: 'meme', label: 'Meme'),
];
