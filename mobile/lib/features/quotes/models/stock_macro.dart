class BrazilMacroDto {
  const BrazilMacroDto({
    this.selic,
    this.selicAsOf,
    this.ipca12m,
    this.ipcaAsOf,
    this.provider = 'brapi',
  });

  final double? selic;
  final String? selicAsOf;
  final double? ipca12m;
  final String? ipcaAsOf;
  final String provider;

  bool get isEmpty => selic == null && ipca12m == null;

  factory BrazilMacroDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return BrazilMacroDto(
      selic: numVal('selic'),
      selicAsOf: json['selic_as_of'] as String?,
      ipca12m: numVal('ipca_12m'),
      ipcaAsOf: json['ipca_as_of'] as String?,
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}

class DictionaryFieldDto {
  const DictionaryFieldDto({
    required this.key,
    this.label,
    this.description,
    this.calculation,
    this.category,
  });

  final String key;
  final String? label;
  final String? description;
  final String? calculation;
  final String? category;

  factory DictionaryFieldDto.fromJson(Map<String, dynamic> json) {
    return DictionaryFieldDto(
      key: json['key'] as String,
      label: json['label'] as String?,
      description: json['description'] as String?,
      calculation: json['calculation'] as String?,
      category: json['category'] as String?,
    );
  }
}

class DictionaryResponseDto {
  const DictionaryResponseDto({
    required this.category,
    required this.fields,
    required this.count,
    this.provider = 'brapi',
  });

  final String category;
  final List<DictionaryFieldDto> fields;
  final int count;
  final String provider;

  factory DictionaryResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['fields'] as List<dynamic>? ?? const [];
    return DictionaryResponseDto(
      category: json['category'] as String? ?? 'statistics',
      fields: raw.map((item) => DictionaryFieldDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}
