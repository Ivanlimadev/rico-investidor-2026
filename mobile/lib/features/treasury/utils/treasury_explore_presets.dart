class TreasuryExploreGroup {
  const TreasuryExploreGroup({required this.id, required this.label});

  final String id;
  final String label;
}

const treasuryExploreGroups = [
  TreasuryExploreGroup(id: 'all', label: 'Todos'),
  TreasuryExploreGroup(id: 'selic', label: 'Selic'),
  TreasuryExploreGroup(id: 'prefixado', label: 'Prefixado'),
  TreasuryExploreGroup(id: 'ipca', label: 'IPCA+'),
  TreasuryExploreGroup(id: 'igpm', label: 'IGP-M'),
];
