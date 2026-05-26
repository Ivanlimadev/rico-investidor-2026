import 'package:rico_investidor/models/fii_models.dart';

const _brazilianStates = {
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
  'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
  'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
};

class FiiPropertyStateSlice {
  const FiiPropertyStateSlice({
    required this.state,
    required this.count,
    required this.percent,
  });

  final String state;
  final int count;
  final double percent;
}

String? parsePropertyState(String? address) {
  if (address == null || address.trim().isEmpty) return null;

  final slashMatch = RegExp(r'/([A-Z]{2})\b').allMatches(address);
  for (final match in slashMatch) {
    final uf = match.group(1);
    if (uf != null && _brazilianStates.contains(uf)) return uf;
  }

  final trailingMatch = RegExp(r'[-,\s]([A-Z]{2})\s*$').firstMatch(address.trim());
  if (trailingMatch != null) {
    final uf = trailingMatch.group(1);
    if (uf != null && _brazilianStates.contains(uf)) return uf;
  }

  final tokens = RegExp(r'\b([A-Z]{2})\b').allMatches(address);
  for (final match in tokens) {
    final uf = match.group(1);
    if (uf != null && _brazilianStates.contains(uf)) return uf;
  }

  return null;
}

bool fiiHasRealEstateProperties(FiiDetail detail) {
  if (detail.topProperties.isNotEmpty) return true;
  final count = detail.propertyCount;
  return count != null && count > 0;
}

List<FiiPropertyStateSlice> computePropertyStateSlices(List<FiiProperty> properties) {
  if (properties.isEmpty) return [];

  final revenueTotal = properties
      .map((p) => p.revenuePct ?? 0)
      .fold<double>(0, (sum, value) => sum + value);

  final weights = <String, double>{};
  final counts = <String, int>{};

  for (final property in properties) {
    final state = parsePropertyState(property.address) ?? 'Outros';
    counts[state] = (counts[state] ?? 0) + 1;

    final weight = revenueTotal > 0 ? (property.revenuePct ?? 0) : 1.0;
    weights[state] = (weights[state] ?? 0) + weight;
  }

  final totalWeight = weights.values.fold<double>(0, (sum, value) => sum + value);
  if (totalWeight <= 0) return [];

  final entries = weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (var i = 0; i < entries.length; i++)
      FiiPropertyStateSlice(
        state: entries[i].key,
        count: counts[entries[i].key] ?? 0,
        percent: (entries[i].value / totalWeight) * 100,
      ),
  ];
}
