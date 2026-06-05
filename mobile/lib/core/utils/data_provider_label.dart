/// Rótulos legíveis para provedores de dados da API.
String formatDataProvider(String? provider) {
  final normalized = (provider ?? 'brapi').trim().toLowerCase();
  return switch (normalized) {
    'hybrid' => 'Bolsai + Brapi',
    'bolsai' => 'Bolsai',
    'brapi' => 'Brapi',
    'marketstack' => 'Marketstack',
    'fmp' => 'FMP',
    _ => normalized.isEmpty ? 'Brapi' : normalized[0].toUpperCase() + normalized.substring(1),
  };
}
