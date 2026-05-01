class Country {
  final String id;
  final String nameEn;
  final String nameTh;
  final String url;
  final int version;

  const Country({
    required this.id,
    required this.nameEn,
    required this.nameTh,
    required this.url,
    required this.version,
  });

  factory Country.fromMap(String id, Map<String, dynamic> data) => Country(
    id: id,
    nameEn: (data['name_en'] as String?) ?? id,
    nameTh: (data['name_th'] as String?) ?? id,
    url: (data['url'] as String?) ?? '',
    version: (data['version'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_th': nameTh,
    'url': url,
    'version': version,
  };

  factory Country.fromJson(Map<String, dynamic> j) => Country(
    id: j['id'] as String,
    nameEn: j['name_en'] as String,
    nameTh: j['name_th'] as String,
    url: j['url'] as String,
    version: (j['version'] as num).toInt(),
  );

  /// Built-in default — bundled in app assets
  static const thailand = Country(
    id: 'thailand',
    nameEn: 'Thailand',
    nameTh: 'ไทย',
    url: 'asset://assets/data/thailand.json',
    version: 0,
  );

  bool get isBundled => url.startsWith('asset://');
}
