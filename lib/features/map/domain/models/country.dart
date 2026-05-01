class Country {
  final String id;
  final String nameEn;
  final String nameTh;
  final String url;
  final int version;
  final String? districtsUrl;
  final Map<String, String>? propertyMapping;
  final List<double>? viewBox; // [left, top, right, bottom]

  const Country({
    required this.id,
    required this.nameEn,
    required this.nameTh,
    required this.url,
    required this.version,
    this.districtsUrl,
    this.propertyMapping,
    this.viewBox,
  });

  factory Country.fromMap(String id, Map<String, dynamic> data) => Country(
    id: id,
    nameEn: (data['name_en'] as String?) ?? id,
    nameTh: (data['name_th'] as String?) ?? id,
    url: (data['url'] as String?) ?? '',
    version: (data['version'] as num?)?.toInt() ?? 1,
    districtsUrl: data['districts_url'] as String?,
    propertyMapping: data['property_mapping'] != null 
        ? Map<String, String>.from(data['property_mapping'] as Map) 
        : null,
    viewBox: data['view_box'] != null 
        ? List<double>.from((data['view_box'] as List).map((e) => (e as num).toDouble())) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_th': nameTh,
    'url': url,
    'version': version,
    if (districtsUrl != null) 'districts_url': districtsUrl,
    if (propertyMapping != null) 'property_mapping': propertyMapping,
    if (viewBox != null) 'view_box': viewBox,
  };

  factory Country.fromJson(Map<String, dynamic> j) => Country(
    id: j['id'] as String,
    nameEn: j['name_en'] as String,
    nameTh: j['name_th'] as String,
    url: j['url'] as String,
    version: (j['version'] as num).toInt(),
    districtsUrl: j['districts_url'] as String?,
    propertyMapping: j['property_mapping'] != null 
        ? Map<String, String>.from(j['property_mapping'] as Map) 
        : null,
    viewBox: j['view_box'] != null 
        ? List<double>.from((j['view_box'] as List).map((e) => (e as num).toDouble())) 
        : null,
  );

  /// Built-in default — bundled in app assets
  static const thailand = Country(
    id: 'thailand',
    nameEn: 'Thailand',
    nameTh: 'ไทย',
    url: 'asset://assets/data/thailand.json',
    version: 0,
    districtsUrl: 'asset://assets/data/districts_full.geojson',
    propertyMapping: {
      'province': 'pro_en',
      'district': 'amp_en',
    },
  );

  bool get isBundled => url.startsWith('asset://');
}
