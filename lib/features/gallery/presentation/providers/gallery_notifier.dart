import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/province/data/province_data.dart';
import 'package:photo_map/core/services/geo_service.dart';
import 'package:photo_map/core/services/cache_service.dart';
import 'package:photo_map/features/auth/presentation/providers/auth_provider.dart';

class PhotoItem {
  const PhotoItem({
    required this.path,
    required this.country,
    required this.province,
    this.district = '',
    required this.timestamp,
    required this.lat,
    required this.lng,
    this.assetEntity,
  });

  final String path;
  final String country;
  final String province;
  final String district;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final AssetEntity? assetEntity;

  // Both must be non-zero — (0,0) is in the ocean and not a real location
  bool get hasLocation => lat != 0.0 && lng != 0.0;

  PhotoItem copyWith({
    String? country,
    String? province,
    String? district,
    double? lat,
    double? lng,
  }) => PhotoItem(
    path: path,
    country: country ?? this.country,
    province: province ?? this.province,
    district: district ?? this.district,
    timestamp: timestamp,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    assetEntity: assetEntity,
  );

  PhotoItem copyWithAsset(AssetEntity asset) => PhotoItem(
    path: path,
    country: country,
    province: province,
    district: district,
    timestamp: timestamp,
    lat: lat,
    lng: lng,
    assetEntity: asset,
  );

  Map<String, dynamic> toJson() => {
    'id': path,
    'country': country,
    'province': province,
    'district': district,
    'timestamp': timestamp.toIso8601String(),
    'lat': lat,
    'lng': lng,
  };

  factory PhotoItem.fromJson(Map<String, dynamic> json, [AssetEntity? asset]) =>
      PhotoItem(
        path: json['id'] as String,
        country: json['country'] as String,
        province: json['province'] as String,
        district: (json['district'] as String?) ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        assetEntity: asset,
      );
}

class GalleryState {
  const GalleryState({
    required this.allPhotos,
    required this.selectedCountry,
    required this.selectedProvince,
    required this.isLoading,
    required this.isGeocoding,
    this.geocodeProcessed = 0,
    this.geocodeTotal = 0,
    this.loadedFromCache = false,
    this.isFirstTimeNoCache = false,
    required this.error,
  });

  final List<PhotoItem> allPhotos;
  final String selectedCountry;
  final String selectedProvince;
  final bool isLoading;
  final bool isGeocoding;
  final int geocodeProcessed;
  final int geocodeTotal;
  final bool loadedFromCache;
  final bool isFirstTimeNoCache;
  final String? error;

  double get geocodeProgress =>
      geocodeTotal > 0 ? geocodeProcessed / geocodeTotal : 0.0;

  GalleryState copyWith({
    List<PhotoItem>? allPhotos,
    String? selectedCountry,
    String? selectedProvince,
    bool? isLoading,
    bool? isGeocoding,
    int? geocodeProcessed,
    int? geocodeTotal,
    bool? loadedFromCache,
    bool? isFirstTimeNoCache,
    String? error,
  }) => GalleryState(
    allPhotos: allPhotos ?? this.allPhotos,
    selectedCountry: selectedCountry ?? this.selectedCountry,
    selectedProvince: selectedProvince ?? this.selectedProvince,
    isLoading: isLoading ?? this.isLoading,
    isGeocoding: isGeocoding ?? this.isGeocoding,
    geocodeProcessed: geocodeProcessed ?? this.geocodeProcessed,
    geocodeTotal: geocodeTotal ?? this.geocodeTotal,
    loadedFromCache: loadedFromCache ?? this.loadedFromCache,
    isFirstTimeNoCache: isFirstTimeNoCache ?? this.isFirstTimeNoCache,
    error: error,
  );

  /// Photos for current album drill-down selection.
  List<PhotoItem> get filteredPhotos {
    if (selectedCountry == 'All') return allPhotos;
    final byCountry = allPhotos.where((p) => p.country == selectedCountry);
    if (selectedProvince == 'All') return byCountry.toList();
    return byCountry.where((p) {
      final prov = p.province.isEmpty ? 'Unknown' : p.province;
      return prov == selectedProvince;
    }).toList();
  }

  /// Unique countries present in loaded photos.
  List<String> get availableCountries {
    final set = <String>{};
    for (final p in allPhotos) {
      set.add(p.country.isEmpty ? 'Unknown' : p.country);
    }
    return set.toList()..sort();
  }

  /// Unique provinces for a given country.
  List<String> availableProvinces(String country) {
    final source = country == 'All'
        ? allPhotos
        : allPhotos.where((p) {
            final c = p.country.isEmpty ? 'Unknown' : p.country;
            return c == country;
          }).toList();
    final set = <String>{};
    for (final p in source) {
      set.add(p.province.isEmpty ? 'Unknown' : p.province);
    }
    return set.toList()..sort();
  }

  /// Photos grouped by country for album view.
  Map<String, List<PhotoItem>> get photosByCountry {
    final map = <String, List<PhotoItem>>{};
    for (final p in allPhotos) {
      final key = p.country.isEmpty ? 'Unknown' : p.country;
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }

  /// Photos grouped by province for a given country.
  Map<String, List<PhotoItem>> photosByProvince(String country) {
    final map = <String, List<PhotoItem>>{};
    for (final p in allPhotos) {
      final c = p.country.isEmpty ? 'Unknown' : p.country;
      if (c != country) continue;
      final key = p.province.isEmpty ? 'Unknown' : p.province;
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }

  /// Photos grouped by district for a given province.
  Map<String, List<PhotoItem>> photosByDistrict(String province) {
    final map = <String, List<PhotoItem>>{};
    for (final p in allPhotos) {
      final prov = p.province.isEmpty ? 'Unknown' : p.province;
      if (prov != province) continue;
      final key = p.district.isEmpty ? 'Unknown' : p.district;
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }
}

final galleryStateProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
      return GalleryNotifier(ref);
    });

class GalleryNotifier extends StateNotifier<GalleryState> {
  final Ref _ref;
  final GeoService _geoService = GeoService();
  final CacheService _cacheService = CacheService();
  final Map<String, ({String country, String province, String district})>
  _geocodingCache = {};
  final Set<String> _deletedAssetIds = {};
  bool _isSilentReloading = false;

  GalleryNotifier(this._ref)
    : super(
        const GalleryState(
          allPhotos: [],
          selectedCountry: 'All',
          selectedProvince: 'All',
          isLoading: false,
          isGeocoding: false,
          error: null,
        ),
      ) {
    _listenToAuth();
  }

  bool _isInitialized = false;

  void _listenToAuth() {
    _ref.listen<AuthState>(
      authNotifierProvider,
      (previous, next) {
        if (next.status == AuthStatus.authenticated && !_isInitialized) {
          _isInitialized = true;
          _initAndLoad();
        } else if (next.status != AuthStatus.authenticated) {
          _isInitialized = false;
        }
      },
      fireImmediately: true,
    );
  }
  Future<void> _initAndLoad() async {
    await _geoService.initialize();

    // Load Geocoding Cache from disk
    final savedGeo = await _cacheService.loadGeoCache();
    if (savedGeo != null && savedGeo.isNotEmpty) {
      savedGeo.forEach((key, val) {
        final data = val as Map<String, dynamic>;
        _geocodingCache[key] = (
          country: data['country'] as String,
          province: data['province'] as String,
          district: (data['district'] as String?) ?? '',
        );
      });
      state = state.copyWith(isFirstTimeNoCache: false);
    } else {
      state = state.copyWith(isFirstTimeNoCache: true);
    }

    // Restore photo metadata from disk so UI has data instantly on resume
    // Prevents "no photo" / 0% achievement flash while PhotoManager re-scans.
    final cachedPhotos = await _cacheService.loadPhotoMetadata();
    if (cachedPhotos != null && cachedPhotos.isNotEmpty) {
      await _loadFromCache(cachedPhotos);
    }

    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.common,
          mediaLocation: true,
        ),
      ),
    );

    if (!permission.hasAccess) {
      state = state.copyWith(
        isLoading: false,
        error: 'Photo permission denied. Please allow access in Settings.',
      );
      return;
    }

    // Listen for photo library changes (screenshot, new photo, deletion)
    PhotoManager.addChangeCallback(_onPhotoLibraryChanged);
    PhotoManager.startChangeNotify();

    await _loadAll();
  }

  Timer? _changeDebounce;

  void _onPhotoLibraryChanged(MethodCall call) {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      silentReload();
    });
  }

  @override
  void dispose() {
    PhotoManager.removeChangeCallback(_onPhotoLibraryChanged);
    PhotoManager.stopChangeNotify();
    super.dispose();
  }

  Future<void> _loadFromCache(List<Map<String, dynamic>> cachedData) async {
    final cachedItems = cachedData.map((j) => PhotoItem.fromJson(j)).toList();
    state = state.copyWith(allPhotos: cachedItems, loadedFromCache: true);
  }

  Future<void> _loadAll({bool isSilent = false}) async {
    // Only show loading spinner if we have no photos yet. 
    // If we already have photos, do a silent update to prevent flickering.
    final shouldShowSpinner = !isSilent && state.allPhotos.isEmpty;
    if (shouldShowSpinner) {
      state = state.copyWith(isLoading: true, error: null);
    }
    
    try {
      List<AssetPathEntity> albums = [];
      for (int attempt = 0; attempt < 3; attempt++) {
        albums = await PhotoManager.getAssetPathList(
          onlyAll: true,
          filterOption: FilterOptionGroup(
            orders: [
              const OrderOption(type: OrderOptionType.createDate, asc: false),
            ],
          ),
        );
        if (albums.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (albums.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final album = albums.first;
      final total = await album.assetCountAsync;

      // Don't wipe existing photos if PhotoManager transiently reports 0 on resume.
      // Real "no photos" only matters on first load (state.allPhotos is empty).
      if (total == 0) {
        if (state.allPhotos.isEmpty) {
          state = state.copyWith(allPhotos: [], isLoading: false);
        } else {
          state = state.copyWith(isLoading: false);
        }
        return;
      }

      final assets = await album.getAssetListRange(start: 0, end: total);

      // Preserve existing geocoding data by matching with current state
      final currentMap = {for (final p in state.allPhotos) p.path: p};
      final photos = _buildPhotoItems(assets, currentMap);

      // Guard: if scanner returned far fewer items than current state, treat as
      // a transient partial scan and keep the existing list to avoid flicker.
      if (state.allPhotos.isNotEmpty &&
          photos.length < state.allPhotos.length * 0.5) {
        state = state.copyWith(isLoading: false);
        return;
      }

      state = state.copyWith(allPhotos: photos, isLoading: false);
      _geocodePhotos(photos).catchError((_) {
        state = state.copyWith(
          isGeocoding: false,
          geocodeProcessed: 0,
          geocodeTotal: 0,
        );
      });
    } catch (e) {
      final msg = e.toString().contains('Permission')
          ? 'Photo permission denied. Please allow access in Settings.'
          : 'Failed to load photos: ${e.toString().replaceFirst('Exception: ', '')}';
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  List<PhotoItem> _buildPhotoItems(
    List<AssetEntity> assets, [
    Map<String, PhotoItem>? existing,
  ]) {
    final items = <PhotoItem>[];
    for (final asset in assets) {
      if (asset.type == AssetType.image || asset.type == AssetType.video) {
        // 1. Try to reuse exactly same object from previous state (preserves geocoding)
        final prev = existing?[asset.id];
        if (prev != null && prev.province.isNotEmpty) {
          items.add(prev.copyWithAsset(asset));
          continue;
        }

        // 2. If new asset, try to find geocoding in our in-memory cache by coordinates
        // This is the KEY FIX for the "No photos in" issue on resume.
        final lat = asset.latitude ?? 0.0;
        final lng = asset.longitude ?? 0.0;
        
        // Match coord key with 4 decimal precision (standard for our cache)
        final coordKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
        final cachedGeo = _geocodingCache[coordKey];

        items.add(
          PhotoItem(
            path: asset.id,
            country: cachedGeo?.country ?? '',
            province: cachedGeo?.province ?? '',
            district: cachedGeo?.district ?? '',
            timestamp: asset.createDateTime,
            lat: lat,
            lng: lng,
            assetEntity: asset,
          ),
        );
      }
    }
    return items;
  }

  Future<void> _geocodePhotos(List<PhotoItem> photos) async {
    if (state.isGeocoding) return;
    state = state.copyWith(
      isGeocoding: true,
      geocodeProcessed: 0,
      geocodeTotal: photos.length,
    );
    try {
      // Step 1: fetch coordinates via latlngAsync for photos missing GPS data
    final List<PhotoItem> withCoords = List.from(photos);

    // Batch process coordinates to avoid overloading the platform channel
    const int batchSize = 200;
    for (int i = 0; i < withCoords.length; i += batchSize) {
      final int end = (i + batchSize < withCoords.length)
          ? i + batchSize
          : withCoords.length;
      final List<Future<void>> batchFutures = [];

      for (int j = i; j < end; j++) {
        final currentPhoto = withCoords[j];
        if (currentPhoto.hasLocation || currentPhoto.assetEntity == null) {
          continue;
        }

        final photoIdx = j;
        batchFutures.add(() async {
          try {
            final ll = await currentPhoto.assetEntity!.latlngAsync();
            if (ll != null && ll.latitude != 0) {
              withCoords[photoIdx] = currentPhoto.copyWith(
                lat: ll.latitude,
                lng: ll.longitude,
              );
            }
          } catch (_) {}
        }());
      }
      if (batchFutures.isNotEmpty) {
        await Future.wait(batchFutures);
        // Small delay to keep the UI responsive
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Update state after each batch so map can show photos progressively
      state = state.copyWith(
        allPhotos: withCoords
            .where((p) => !_deletedAssetIds.contains(p.path))
            .toList(),
        geocodeProcessed: end,
      );

      // Run offline GeoJSON matching on what we have so far
      _applyOfflineGeo(withCoords.sublist(0, end));
    }

    // Step 2: collect unique coordinate clusters for online geocoding
    final pending = <String, ({double lat, double lng})>{};
    for (final photo in withCoords) {
      if (!photo.hasLocation) continue;
      final key =
          '${photo.lat.toStringAsFixed(4)}_${photo.lng.toStringAsFixed(4)}';
      pending[key] = (lat: photo.lat, lng: photo.lng);
    }
    if (pending.isEmpty) {
      state = state.copyWith(
        isGeocoding: false,
        geocodeProcessed: 0,
        geocodeTotal: 0,
      );
      return;
    }

    // Full offline pass to catch any remaining
    _applyOfflineGeo(withCoords);

    // Step 3: Lazy Background Online Pass (Internet geocoding with throttling prevention)
    final resolved =
        <String, ({String country, String province, String district})>{};

    // Seed resolved with what offline pass already found
    for (final photo in state.allPhotos) {
      if (!photo.hasLocation || photo.province.isEmpty) continue;
      final key =
          '${photo.lat.toStringAsFixed(4)}_${photo.lng.toStringAsFixed(4)}';
      resolved[key] = (
        country: photo.country,
        province: photo.province,
        district: photo.district,
      );
    }

    final needsOnline = pending.keys.where((k) {
      final r = resolved[k];
      return r == null || r.province.isEmpty || r.district.isEmpty;
    }).toList();

    for (int i = 0; i < needsOnline.length; i++) {
      final key = needsOnline[i];
      if (!state.isGeocoding) break;

      final coords = pending[key]!;
      try {
        final placemarks = await placemarkFromCoordinates(
          coords.lat,
          coords.lng,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;

          final country = pm.country ?? 'Unknown';
          String province = _cleanProvinceName(pm.administrativeArea ?? '');
          if (province.isEmpty || province == 'Unknown') {
            final subProvince = _cleanProvinceName(
              pm.subAdministrativeArea ?? '',
            );
            if (subProvince.isNotEmpty) province = subProvince;
          }
          final district = _cleanDistrictName(
            pm.subAdministrativeArea ?? pm.locality ?? '',
          );

          final existing = resolved[key];
          resolved[key] = (
            country: country,
            province: (existing != null && country == 'Thailand')
                ? existing.province
                : province,
            district: district,
          );

          _geocodingCache[key] = resolved[key]!;
          _applyResolved(resolved);
        }
        await Future.delayed(const Duration(milliseconds: 1500));
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 2000));
      }
    }

    _persistAll();
    } finally {
      state = state.copyWith(
        isGeocoding: false,
        geocodeProcessed: 0,
        geocodeTotal: 0,
      );
    }
  }

  /// Run offline GeoJSON matching and apply results immediately.
  void _applyOfflineGeo(List<PhotoItem> photos) {
    final resolved =
        <String, ({String country, String province, String district})>{};

    for (final photo in photos) {
      if (!photo.hasLocation) continue;
      final key =
          '${photo.lat.toStringAsFixed(4)}_${photo.lng.toStringAsFixed(4)}';

      // Skip if already resolved
      if (photo.province.isNotEmpty) continue;

      // Check geocoding cache first
      final cached = _geocodingCache[key];
      if (cached != null) {
        resolved[key] = cached;
        continue;
      }

      final geoProvince = _geoService.getProvince(photo.lat, photo.lng);
      if (geoProvince != null) {
        String provinceName = geoProvince;
        for (final p in thaiProvinces) {
          if (p.name.replaceAll(RegExp(r'[\s-]'), '').toLowerCase() ==
              geoProvince) {
            provinceName = p.name;
            break;
          }
        }
        resolved[key] = (
          country: 'Thailand',
          province: provinceName,
          district: '',
        );
      }
    }

    if (resolved.isNotEmpty) {
      _applyResolved(resolved);
    }
  }

  Future<void> _persistAll() async {
    // 1. Photo metadata
    final photoJson = state.allPhotos.map((p) => p.toJson()).toList();
    _cacheService.savePhotoMetadata(photoJson);

    // 2. Geocoding results
    final geoJson = _geocodingCache.map(
      (key, val) => MapEntry(key, {
        'country': val.country,
        'province': val.province,
        'district': val.district,
      }),
    );
    _cacheService.saveGeoCache(geoJson);
  }

  void _applyResolved(
    Map<String, ({String country, String province, String district})> resolved,
  ) {
    final updated = state.allPhotos.map((photo) {
      if (!photo.hasLocation) {
        return photo.country.isEmpty
            ? photo.copyWith(country: 'Unknown')
            : photo;
      }

      final key =
          '${photo.lat.toStringAsFixed(4)}_${photo.lng.toStringAsFixed(4)}';
      final loc = resolved[key];
      if (loc == null) return photo;

      return photo.copyWith(
        country: photo.country.isEmpty || photo.country == 'Unknown'
            ? loc.country
            : photo.country,
        province: photo.province.isEmpty ? loc.province : photo.province,
        district: photo.district.isEmpty ? loc.district : photo.district,
      );
    }).toList();

    state = state.copyWith(
      allPhotos: updated
          .where((p) => !_deletedAssetIds.contains(p.path))
          .toList(),
    );
    _persistAll(); // Save incrementally
  }

  static String _cleanDistrictName(String raw) {
    if (raw.isEmpty) return '';
    String cleaned = raw
        .replaceAll(RegExp(r'^อำเภอ\s*'), '')
        .replaceAll(RegExp(r'^เขต\s*'), '')
        .replaceAll(RegExp(r'^แขวง\s*'), '')
        .replaceAll(RegExp(r'\s*District$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Subdistrict$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d{5}'), '')
        .trim();
    return cleaned;
  }

  static String _cleanProvinceName(String raw) {
    if (raw.isEmpty) return '';

    // Strip zip codes (5 digits)
    String cleaned = raw.replaceAll(RegExp(r'\d{5}'), '');

    // Strip Thai/English province/district prefixes and suffixes
    cleaned = cleaned
        .replaceAll(RegExp(r'^จังหวัด\s*'), '')
        .replaceAll(RegExp(r'\s*จังหวัด$'), '')
        .replaceAll(RegExp(r'^อำเภอ\s*'), '')
        .replaceAll(RegExp(r'^เขต\s*'), '')
        .replaceAll(RegExp(r'\s*Province$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Prefecture$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Oblast$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*District$', caseSensitive: false), '')
        .trim();

    if (cleaned.isEmpty) return '';

    // Canonical Thai name remaps
    const remaps = <String, String>{
      'Krung Thep Maha Nakhon': 'Bangkok',
      'Bangkok City': 'Bangkok',
      'Krung Thep': 'Bangkok',
    };
    if (remaps.containsKey(cleaned)) return remaps[cleaned]!;

    // Exact match against canonical province list (case-insensitive, spaces-insensitive)
    final normalizedInput = cleaned.replaceAll(' ', '').toLowerCase();
    for (final p in thaiProvinces) {
      final normalizedP = p.name.replaceAll(' ', '').toLowerCase();
      if (normalizedP == normalizedInput) return p.name;
    }

    // Try to find a province name contained WITHIN the string
    for (final p in thaiProvinces) {
      final normalizedP = p.name.replaceAll(' ', '').toLowerCase();
      if (normalizedInput.contains(normalizedP)) {
        return p.name;
      }
    }

    return cleaned;
  }

  void selectCountry(String country) =>
      state = state.copyWith(selectedCountry: country, selectedProvince: 'All');

  void selectProvince(String province) =>
      state = state.copyWith(selectedProvince: province);

  void addPhoto(String path, String province) {
    final country = state.selectedCountry == 'All'
        ? 'Unknown'
        : state.selectedCountry;
    final photo = PhotoItem(
      path: path,
      country: country,
      province: province == 'All' ? '' : province,
      timestamp: DateTime.now(),
      lat: 0,
      lng: 0,
    );
    state = state.copyWith(allPhotos: [photo, ...state.allPhotos]);
  }

  /// Remove photo from state only (already deleted from device).
  void removeFromState(String photoPath) {
    _deletedAssetIds.add(photoPath);
    state = state.copyWith(
      allPhotos: state.allPhotos.where((p) => p.path != photoPath).toList(),
    );
    _persistAll();
  }

  /// Remove photo by its unique path and delete it from the device.
  /// Returns true if the photo was actually deleted (user confirmed on iOS).
  Future<bool> removePhoto(String photoPath) async {
    final deleted = await PhotoManager.editor.deleteWithIds([photoPath]);
    if (deleted.isNotEmpty) {
      _deletedAssetIds.add(photoPath);
      state = state.copyWith(
        allPhotos: state.allPhotos.where((p) => p.path != photoPath).toList(),
      );
      _persistAll();
      return true;
    }
    return false;
  }

  /// Remove multiple photos by their paths and delete them from the device.
  Future<List<String>> removePhotos(List<String> paths) async {
    final deleted = await PhotoManager.editor.deleteWithIds(paths);
    if (deleted.isNotEmpty) {
      _deletedAssetIds.addAll(paths);
      final pathsSet = paths.toSet();
      state = state.copyWith(
        allPhotos: state.allPhotos
            .where((p) => !pathsSet.contains(p.path))
            .toList(),
      );
      _persistAll();
    }
    return deleted;
  }

  /// Update country/province for a photo identified by its path.
  void updatePhotoLocation(
    String photoPath,
    String newCountry,
    String newProvince,
  ) {
    state = state.copyWith(
      allPhotos: state.allPhotos.map((p) {
        if (p.path != photoPath) return p;
        return p.copyWith(country: newCountry, province: newProvince);
      }).toList(),
    );
  }

  Future<void> reloadPhotos() => _loadAll();

  /// Reload without spinner — adds new photos and re-geocodes any that still
  /// lack coordinates (e.g. user just added location in iOS Photos).
  Future<void> silentReload() async {
    if (_isSilentReloading) return;
    _isSilentReloading = true;
    try {
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (albums.isEmpty) return;

      final album = albums.first;
      final total = await album.assetCountAsync;
      // Don't wipe state if PhotoManager transiently reports 0 on resume.
      if (total == 0) {
        if (state.allPhotos.isEmpty) {
          state = state.copyWith(allPhotos: []);
        }
        return;
      }

      final assets = await album.getAssetListRange(start: 0, end: total);

      // Preserve existing geocoded data
      final currentMap = {for (final p in state.allPhotos) p.path: p};
      final photos = _buildPhotoItems(assets, currentMap);

      // Filter deleted + deduplicate
      final uniqueMap = <String, PhotoItem>{};
      for (final p in photos) {
        if (!_deletedAssetIds.contains(p.path)) {
          uniqueMap[p.path] = p;
        }
      }
      final finalPhotos = uniqueMap.values.toList();

      // Guard against partial scans on resume — don't shrink the list drastically.
      if (state.allPhotos.isNotEmpty &&
          finalPhotos.length < state.allPhotos.length * 0.5) {
        return;
      }

      state = state.copyWith(allPhotos: finalPhotos);

      // Geocode any items that don't have location yet
      final pendingGeocode = finalPhotos.where((p) => !p.hasLocation).toList();
      if (pendingGeocode.isNotEmpty) {
        _geocodePhotos(pendingGeocode).catchError((_) {
          state = state.copyWith(
            isGeocoding: false,
            geocodeProcessed: 0,
            geocodeTotal: 0,
          );
        });
      }
    } catch (_) {
      // Silent fail — don't disrupt the UI on background refresh
    } finally {
      _isSilentReloading = false;
    }
}
}
