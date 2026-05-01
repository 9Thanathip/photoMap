import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/domain/models/country.dart';
import '../widgets/province_map_painter.dart';
import 'country_provider.dart';

class ProvinceMapState {
  final String countryId;
  final String provinceName;
  final List<DistrictShape> districts;
  final ui.Path? combinedPath;
  final Map<String, ui.Image?> districtPhotos;
  final Map<String, DateTime> imageLoadTimes;
  final bool isLoading;
  final String? error;

  final Map<String, List<PhotoItem>> allPhotosByDistrict;

  ProvinceMapState({
    required this.countryId,
    required this.provinceName,
    required this.districts,
    this.combinedPath,
    required this.districtPhotos,
    required this.allPhotosByDistrict,
    required this.imageLoadTimes,
    required this.isLoading,
    this.error,
  });

  ProvinceMapState copyWith({
    String? countryId,
    String? provinceName,
    List<DistrictShape>? districts,
    ui.Path? combinedPath,
    Map<String, ui.Image?>? districtPhotos,
    Map<String, List<PhotoItem>>? allPhotosByDistrict,
    Map<String, DateTime>? imageLoadTimes,
    bool? isLoading,
    String? error,
  }) => ProvinceMapState(
    countryId: countryId ?? this.countryId,
    provinceName: provinceName ?? this.provinceName,
    districts: districts ?? this.districts,
    combinedPath: combinedPath ?? this.combinedPath,
    districtPhotos: districtPhotos ?? this.districtPhotos,
    allPhotosByDistrict: allPhotosByDistrict ?? this.allPhotosByDistrict,
    imageLoadTimes: imageLoadTimes ?? this.imageLoadTimes,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class ProvinceMapParams {
  final String countryId;
  final String provinceName;

  ProvinceMapParams({required this.countryId, required this.provinceName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProvinceMapParams &&
          runtimeType == other.runtimeType &&
          countryId == other.countryId &&
          provinceName == other.provinceName;

  @override
  int get hashCode => countryId.hashCode ^ provinceName.hashCode;
}

final provinceMapProvider =
    StateNotifierProvider.family<ProvinceMapNotifier, ProvinceMapState, ProvinceMapParams>(
      (ref, params) {
        final notifier = ProvinceMapNotifier(ref, params);
        notifier.loadMap();
        return notifier;
      },
    );

class ProvinceMapNotifier extends StateNotifier<ProvinceMapState> {
  final Ref _ref;
  final ProvinceMapParams params;

  ProvinceMapNotifier(this._ref, this.params)
    : super(
        ProvinceMapState(
          countryId: params.countryId,
          provinceName: params.provinceName,
          districts: [],
          districtPhotos: {},
          allPhotosByDistrict: {},
          imageLoadTimes: {},
          isLoading: true,
        ),
      ) {
    _ref.listen(galleryStateProvider, (previous, next) {
      if (previous?.allPhotos != next.allPhotos) {
        _updateDistrictPhotos();
      }
    });
  }

  Future<void> loadMap() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Find country info
      final countries = _ref.read(countryProvider).available;
      final country = countries.firstWhere((c) => c.id == params.countryId, orElse: () => Country.thailand);

      final shapes = await _loadDistrictShapes(country, params.provinceName);

      if (shapes.isEmpty) {
        throw Exception("No districts found for ${params.provinceName}");
      }

      final combined = ui.Path();
      for (final s in shapes) {
        combined.addPath(s.path, ui.Offset.zero);
      }

      state = state.copyWith(
        districts: shapes,
        combinedPath: combined,
        isLoading: false,
      );
      await _updateDistrictPhotos();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to load district boundaries.",
      );
    }
  }

  Future<List<DistrictShape>> _loadDistrictShapes(Country country, String province) async {
    String jsonString;
    if (country.isBundled && country.districtsUrl != null) {
      final assetPath = country.districtsUrl!.replaceFirst('asset://', '');
      jsonString = await rootBundle.loadString(assetPath);
    } else if (country.districtsUrl != null) {
      // Download or load from cache using CountryRepository
      final repo = _ref.read(countryProvider.notifier).repo;
      // We need a way to load districts geojson. 
      // Reusing loadGeoJson by creating a temporary Country object for the districts file
      final districtsCountry = Country(
        id: '${country.id}_districts',
        nameEn: '', nameTh: '',
        url: country.districtsUrl!,
        version: country.version,
      );
      
      try {
        jsonString = await repo.loadGeoJson(districtsCountry);
      } catch (_) {
        // If not cached, download it
        await repo.download(districtsCountry);
        jsonString = await repo.loadGeoJson(districtsCountry);
      }
    } else {
      return [];
    }

    final data = json.decode(jsonString);
    final List<DistrictShape> shapes = [];

    final normalizedProvince = province
        .replaceAll(RegExp(r'[\s-]'), '')
        .toLowerCase();

    // Mapping from Country info or defaults
    final provinceProp = country.propertyMapping?['province'] ?? 'pro_en';
    final districtProp = country.propertyMapping?['district'] ?? 'amp_en';

    if (data['features'] != null) {
      for (var feature in data['features']) {
        final props = feature['properties'];
        
        // Try multiple common property names if direct mapping fails
        final proVal = (props[provinceProp] ?? props['NAME_1'] ?? props['name_1'] ?? '').toString();

        // Normalize for match
        final normalizedProVal = proVal
            .replaceAll(RegExp(r'[\s-]'), '')
            .toLowerCase();

        if (normalizedProVal == normalizedProvince) {
          final distVal = (props[districtProp] ?? props['NAME_2'] ?? props['name_2'] ?? 'Unknown').toString();
          final geometry = feature['geometry'];
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];

          final path = ui.Path();
          if (type == 'Polygon') {
            _addPolygonToPath(path, coordinates[0]);
          } else if (type == 'MultiPolygon') {
            for (var polygon in coordinates) {
              _addPolygonToPath(path, polygon[0]);
            }
          }
          shapes.add(DistrictShape(name: distVal, path: path));
        }
      }
    }
    return shapes;
  }

  void _addPolygonToPath(ui.Path path, List coordinates) {
    if (coordinates.isEmpty) return;
    path.moveTo(coordinates[0][0].toDouble(), -coordinates[0][1].toDouble());
    for (var i = 1; i < coordinates.length; i++) {
      path.lineTo(coordinates[i][0].toDouble(), -coordinates[i][1].toDouble());
    }
    path.close();
  }

  final Map<String, ui.Image?> _imageCache = {};

  Future<void> _updateDistrictPhotos() async {
    final allGalleryPhotos = _ref.read(galleryStateProvider).allPhotos;
    final normalizedProvince = state.provinceName
        .replaceAll(RegExp(r'[\s-]'), '')
        .toLowerCase();

    final provincePhotos = allGalleryPhotos.where((p) {
      // Filter by country AND province to be safe
      if (p.country.replaceAll(RegExp(r'[\s-]'), '').toLowerCase() != 
          state.countryId.replaceAll(RegExp(r'[\s-]'), '').toLowerCase()) {
        return false;
      }
      final pProv = p.province.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
      return pProv == normalizedProvince;
    }).toList();

    final Map<String, List<PhotoItem>> photosByDistrict = {};

    final Map<String, String> normalizedToRealDistrict = {};
    for (final d in state.districts) {
      final normalized = d.name.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
      normalizedToRealDistrict[normalized] = d.name;
    }

    for (final photo in provincePhotos) {
      String? matchedDistrict;

      if (photo.hasLocation) {
        final point = ui.Offset(photo.lng, -photo.lat);
        for (final district in state.districts) {
          if (district.path.contains(point)) {
            matchedDistrict = district.name;
            break;
          }
        }
      }

      if (matchedDistrict == null && photo.district.isNotEmpty) {
        final photoDistNormalized = photo.district
            .replaceAll(RegExp(r'[\s-]'), '')
            .toLowerCase();
        for (final entry in normalizedToRealDistrict.entries) {
          if (entry.key == photoDistNormalized ||
              entry.key.contains(photoDistNormalized) ||
              photoDistNormalized.contains(entry.key)) {
            matchedDistrict = entry.value;
            break;
          }
        }
      }

      final districtKey = matchedDistrict ?? 'Unknown';
      photosByDistrict.putIfAbsent(districtKey, () => []).add(photo);
    }

    final Map<String, ui.Image?> newPhotos = {};
    final newLoadTimes = Map<String, DateTime>.from(state.imageLoadTimes);

    final Map<String, AssetEntity> districtSelectedPhotos = {};
    for (var entry in photosByDistrict.entries) {
      final districtName = entry.key;
      final photos = List<PhotoItem>.from(entry.value)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (districtName != 'Unknown' && photos.isNotEmpty) {
        final photo = photos.first;
        if (photo.assetEntity != null) {
          districtSelectedPhotos[districtName] = photo.assetEntity!;
        }
      }
    }

    final List<Future<void>> futures = [];
    for (var entry in districtSelectedPhotos.entries) {
      futures.add(() async {
        final districtName = entry.key;
        final entity = entry.value;

        if (_imageCache.containsKey(entity.id)) {
          newPhotos[districtName] = _imageCache[entity.id];
          return;
        }

        final img = await _loadUiImage(entity);
        if (img != null) {
          _imageCache[entity.id] = img;
          newPhotos[districtName] = img;
        }
      }());
    }

    await Future.wait(futures);

    const staggerMs = 80;
    final now = DateTime.now();
    final newKeys = newPhotos.keys
        .where((k) => !state.districtPhotos.containsKey(k))
        .toList();
    for (var i = 0; i < newKeys.length; i++) {
      newLoadTimes[newKeys[i]] = now.add(Duration(milliseconds: i * staggerMs));
    }

    state = state.copyWith(
      districtPhotos: newPhotos,
      allPhotosByDistrict: photosByDistrict,
      imageLoadTimes: newLoadTimes,
    );
  }

  Future<ui.Image?> _loadUiImage(AssetEntity entity) async {
    final byteData = await entity.thumbnailDataWithSize(
      const ThumbnailSize(400, 400),
    );
    if (byteData == null) return null;

    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(byteData, (img) => completer.complete(img));
    return completer.future;
  }
}
