import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager/photo_manager.dart';

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

  bool get hasLocation => lat != 0.0 || lng != 0.0;

  PhotoItem copyWith({String? country, String? province}) => PhotoItem(
        path: path,
        country: country ?? this.country,
        province: province ?? this.province,
        timestamp: timestamp,
        lat: lat,
        lng: lng,
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
  GalleryNotifier()
      : super(const GalleryState(
          allPhotos: [],
          selectedCountry: 'All',
          selectedProvince: 'All',
          isLoading: false,
          isGeocoding: false,
          error: null,
        )) {
    Future.delayed(const Duration(milliseconds: 300), _loadAll);
  }

  Future<void> _loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final albums = await PhotoManager.getAssetPathList(onlyAll: true);
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
      if (asset.type == AssetType.image) {
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
    final List<PhotoItem> withCoords = [];
    for (final photo in photos) {
      if (photo.hasLocation || photo.assetEntity == null) {
        withCoords.add(photo);
        continue;
      }
      try {
        final ll = await photo.assetEntity!.latlngAsync();
        final lat = ll?.latitude ?? 0.0;
        final lng = ll?.longitude ?? 0.0;
        withCoords.add(PhotoItem(
          path: photo.path,
          country: photo.country,
          province: photo.province,
          timestamp: photo.timestamp,
          lat: lat,
          lng: lng,
          assetEntity: photo.assetEntity,
        ));
      } catch (_) {
        withCoords.add(photo);
      }
    }
    state = state.copyWith(allPhotos: withCoords);

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
      try {
        final placemarks = await placemarkFromCoordinates(
          entry.value.lat,
          entry.value.lng,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          resolved[entry.key] = (
            country: pm.country ?? 'Unknown',
            province: _cleanProvinceName(pm.administrativeArea ?? ''),
          );
        }
        await Future.delayed(const Duration(milliseconds: 350));
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
      if (photo.country.isNotEmpty) return photo;
      final key =
          '${photo.lat.toStringAsFixed(2)}_${photo.lng.toStringAsFixed(2)}';
      final loc = resolved[key];
      if (loc == null) return photo;
      return photo.copyWith(country: loc.country, province: loc.province);
    }).toList();

    state = state.copyWith(allPhotos: updated, isGeocoding: false);
  }

  static String _cleanProvinceName(String raw) {
    return raw
        .replaceAll(RegExp(r'^จังหวัด\s*'), '')
        .replaceAll(RegExp(r'\s*จังหวัด$'), '')
        .replaceAll(RegExp(r'\s*Province$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Prefecture$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Oblast$', caseSensitive: false), '')
        .trim();
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
