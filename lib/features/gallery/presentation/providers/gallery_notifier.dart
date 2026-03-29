import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/province/data/province_data.dart';
import 'package:photo_map/core/services/geo_service.dart';

class PhotoItem {
  const PhotoItem({
    required this.path,
    required this.country,
    required this.province,
    required this.timestamp,
    required this.lat,
    required this.lng,
    this.assetEntity,
  });

  final String path;
  final String country;
  final String province;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final AssetEntity? assetEntity;

  // Both must be non-zero — (0,0) is in the ocean and not a real location
  bool get hasLocation => lat != 0.0 && lng != 0.0;

  PhotoItem copyWith({
    String? country,
    String? province,
    double? lat,
    double? lng,
  }) =>
      PhotoItem(
        path: path,
        country: country ?? this.country,
        province: province ?? this.province,
        timestamp: timestamp,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        assetEntity: assetEntity,
      );
}

class GalleryState {
  const GalleryState({
    required this.allPhotos,
    required this.selectedCountry,
    required this.selectedProvince,
    required this.isLoading,
    required this.isGeocoding,
    required this.error,
  });

  final List<PhotoItem> allPhotos;
  final String selectedCountry;
  final String selectedProvince;
  final bool isLoading;
  final bool isGeocoding;
  final String? error;

  GalleryState copyWith({
    List<PhotoItem>? allPhotos,
    String? selectedCountry,
    String? selectedProvince,
    bool? isLoading,
    bool? isGeocoding,
    String? error,
  }) =>
      GalleryState(
        allPhotos: allPhotos ?? this.allPhotos,
        selectedCountry: selectedCountry ?? this.selectedCountry,
        selectedProvince: selectedProvince ?? this.selectedProvince,
        isLoading: isLoading ?? this.isLoading,
        isGeocoding: isGeocoding ?? this.isGeocoding,
        error: error,
      );

  /// Photos for current album drill-down selection.
  List<PhotoItem> get filteredPhotos {
    if (selectedCountry == 'All') return allPhotos;
    final byCountry =
        allPhotos.where((p) => p.country == selectedCountry);
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
}

final galleryStateProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  return GalleryNotifier();
});

class GalleryNotifier extends StateNotifier<GalleryState> {
  final GeoService _geoService = GeoService();

  GalleryNotifier()
      : super(const GalleryState(
          allPhotos: [],
          selectedCountry: 'All',
          selectedProvince: 'All',
          isLoading: false,
          isGeocoding: false,
          error: null,
        )) {
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await _geoService.initialize();

    // Request permission before loading — critical on first install.
    // On Android 10+, mediaLocation:true is required to read GPS EXIF data.
    // The ACCESS_MEDIA_LOCATION permission must also be declared in AndroidManifest.xml.
    // requestOption is ignored on iOS so this is Android-only behaviour.
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

    await _loadAll();
  }

  Future<void> _loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Retry up to 3 times with delay — iOS may not expose photos immediately
      // after the permission dialog is dismissed for the first time.
      List<AssetPathEntity> albums = [];
      for (int attempt = 0; attempt < 3; attempt++) {
        albums = await PhotoManager.getAssetPathList(onlyAll: true);
        if (albums.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (albums.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final album = albums.first;
      final total = await album.assetCountAsync;
      final assets = await album.getAssetListRange(start: 0, end: total);
      final photos = _buildPhotoItems(assets);
      state = state.copyWith(allPhotos: photos, isLoading: false);
      _geocodePhotos(photos);
    } catch (e) {
      final msg = e.toString().contains('Permission')
          ? 'Photo permission denied. Please allow access in Settings.'
          : 'Failed to load photos: ${e.toString().replaceFirst('Exception: ', '')}';
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  List<PhotoItem> _buildPhotoItems(List<AssetEntity> assets) {
    final items = <PhotoItem>[];
    for (final asset in assets) {
      if (asset.type == AssetType.image || asset.type == AssetType.video) {
        items.add(PhotoItem(
          path: asset.id,
          country: '',
          province: '',
          timestamp: asset.createDateTime,
          lat: asset.latitude ?? 0.0,
          lng: asset.longitude ?? 0.0,
          assetEntity: asset,
        ));
      }
    }
    return items;
  }

  Future<void> _geocodePhotos(List<PhotoItem> photos) async {
    state = state.copyWith(isGeocoding: true);

    // Step 1: fetch coordinates via latlngAsync for photos missing GPS data
    // Step 1: fetch coordinates via latlngAsync for photos missing GPS data
    state = state.copyWith(isGeocoding: true);
    
    final List<PhotoItem> withCoords = List.from(photos);
    
    // Batch process coordinates to avoid overloading the platform channel
    const int batchSize = 30; // smaller batches for reliability
    for (int i = 0; i < withCoords.length; i += batchSize) {
      final int end = (i + batchSize < withCoords.length) ? i + batchSize : withCoords.length;
      final List<Future<void>> batchFutures = [];
      
      for (int j = i; j < end; j++) {
        final currentPhoto = withCoords[j];
        if (currentPhoto.hasLocation || currentPhoto.assetEntity == null) continue;
        
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
        // update UI every 100 items to show progress
        if (i % 100 == 0) {
          state = state.copyWith(allPhotos: List.from(withCoords));
        }
      }
    }
    state = state.copyWith(allPhotos: List.from(withCoords));

    // Step 2: collect unique coordinate clusters for geocoding
    final pending = <String, ({double lat, double lng})>{};
    for (final photo in withCoords) {
      if (!photo.hasLocation) continue;
      final key =
          '${photo.lat.toStringAsFixed(2)}_${photo.lng.toStringAsFixed(2)}';
      pending[key] = (lat: photo.lat, lng: photo.lng);
    }
    if (pending.isEmpty) {
      state = state.copyWith(isGeocoding: false);
      return;
    }

    final resolved = <String, ({String country, String province})>{};
    for (final entry in pending.entries) {
      // 1. Try Offline GeoJSON Lookup FIRST (Physical Boundary matching is 100% accurate)
      final geoProvince = _geoService.getProvince(entry.value.lat, entry.value.lng);
      
      if (geoProvince != null) {
        String provinceName = geoProvince; 
        for (final p in thaiProvinces) {
          if (p.name.replaceAll(RegExp(r'[\s-]'), '').toLowerCase() == geoProvince) {
            provinceName = p.name;
            break;
          }
        }

        resolved[entry.key] = (
          country: 'Thailand',
          province: provinceName,
        );
        continue; // Found province boundary, skip internet geocoding
      }

      // 2. Fallback to Internet Geocoding for countries outside Thailand or missed boundaries
      try {
        final placemarks = await placemarkFromCoordinates(
          entry.value.lat,
          entry.value.lng,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          // Try administrativeArea first, then subAdministrativeArea
          String province = _cleanProvinceName(pm.administrativeArea ?? '');
          if (province.isEmpty || province == 'Unknown') {
            final subProvince = _cleanProvinceName(pm.subAdministrativeArea ?? '');
            if (subProvince.isNotEmpty) province = subProvince;
          }
          
          resolved[entry.key] = (
            country: pm.country ?? 'Unknown',
            province: province,
          );
        }
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        resolved[entry.key] = (country: 'Unknown', province: '');
      }
    }

    final updated = state.allPhotos.map((photo) {
      if (!photo.hasLocation) {
        return photo.country.isEmpty
            ? photo.copyWith(country: 'Unknown')
            : photo;
      }
      
      // If already geocoded, keep it
      if (photo.province.isNotEmpty && photo.country.isNotEmpty) return photo;

      final key =
          '${photo.lat.toStringAsFixed(2)}_${photo.lng.toStringAsFixed(2)}';
      final loc = resolved[key];
      if (loc == null) return photo;
      
      // If photo has no province, use the resolved one
      return photo.copyWith(
        country: photo.country.isEmpty ? loc.country : photo.country, 
        province: photo.province.isEmpty ? loc.province : photo.province,
      );
    }).toList();

    state = state.copyWith(allPhotos: updated, isGeocoding: false);
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
    final country =
        state.selectedCountry == 'All' ? 'Unknown' : state.selectedCountry;
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

  /// Remove photo by its unique path.
  void removePhoto(String photoPath) {
    state = state.copyWith(
      allPhotos: state.allPhotos.where((p) => p.path != photoPath).toList(),
    );
  }

  /// Remove multiple photos by their paths.
  void removePhotos(List<String> paths) {
    final set = paths.toSet();
    state = state.copyWith(
      allPhotos: state.allPhotos.where((p) => !set.contains(p.path)).toList(),
    );
  }

  /// Update country/province for a photo identified by its path.
  void updatePhotoLocation(
      String photoPath, String newCountry, String newProvince) {
    state = state.copyWith(
      allPhotos: state.allPhotos.map((p) {
        if (p.path != photoPath) return p;
        return p.copyWith(country: newCountry, province: newProvince);
      }).toList(),
    );
  }

  Future<void> reloadPhotos() => _loadAll();
}
