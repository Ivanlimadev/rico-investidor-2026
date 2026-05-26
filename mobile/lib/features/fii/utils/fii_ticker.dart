String normalizeFiiTicker(String raw) {
  final cleaned = raw.trim().toUpperCase().replaceAll('.SA', '');
  if (RegExp(r'^[A-Z]{4}\d{2}$').hasMatch(cleaned)) return cleaned;
  if (cleaned.length == 4 && RegExp(r'^[A-Z]+$').hasMatch(cleaned)) {
    return '${cleaned}11';
  }
  return cleaned;
}

bool isFiiTicker(String raw) {
  return RegExp(r'^[A-Z]{4}\d{2}$').hasMatch(normalizeFiiTicker(raw));
}
