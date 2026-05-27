class IndexExploreGroup {
  const IndexExploreGroup({required this.id, required this.label});

  final String id;
  final String label;
}

const indexExploreGroups = [
  IndexExploreGroup(id: 'all', label: 'Todos'),
  IndexExploreGroup(id: 'brasil', label: 'Brasil'),
  IndexExploreGroup(id: 'fiis', label: 'FIIs'),
  IndexExploreGroup(id: 'setorial', label: 'Setorial'),
  IndexExploreGroup(id: 'internacional', label: 'Internacional'),
];
