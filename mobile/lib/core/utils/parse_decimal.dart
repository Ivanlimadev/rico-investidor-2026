double? parseDecimalInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final normalized = trimmed.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.');
  return double.tryParse(normalized);
}
