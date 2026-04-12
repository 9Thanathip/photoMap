import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/presentation/providers/map_provider.dart';
import '../widgets/province_map_painter.dart';

class ProvinceMapState {
  final String provinceName;
  final List<DistrictShape> districts;
  final ui.Path? combinedPath;
  final Map<String, ui.Image?> districtPhotos;
  final Map<String, DateTime> imageLoadTimes;
  final bool isLoading;
  final String? error;

  final Map<String, List<PhotoItem>> allPhotosByDistrict;

  ProvinceMapState({
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
    String? provinceName,
    List<DistrictShape>? districts,
    ui.Path? combinedPath,
    Map<String, ui.Image?>? districtPhotos,
    Map<String, List<PhotoItem>>? allPhotosByDistrict,
    Map<String, DateTime>? imageLoadTimes,
    bool? isLoading,
    String? error,
  }) => ProvinceMapState(
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

final provinceMapProvider =
    StateNotifierProvider.family<ProvinceMapNotifier, ProvinceMapState, String>(
      (ref, provinceName) {
        final notifier = ProvinceMapNotifier(ref, provinceName);
        notifier.loadMap();
        return notifier;
      },
    );

class ProvinceMapNotifier extends StateNotifier<ProvinceMapState> {
  final Ref _ref;
  final String provinceName;

  ProvinceMapNotifier(this._ref, this.provinceName)
    : super(
        ProvinceMapState(
          provinceName: provinceName,
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
      final shapes = await _loadDistrictShapes(provinceName);

      if (shapes.isEmpty) {
        throw Exception("No districts found for $provinceName");
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

  Future<List<DistrictShape>> _loadDistrictShapes(String province) async {
    // We use the full districts file and filter by province
    const path = 'assets/data/districts_full.geojson';

    final String jsonString = await rootBundle.loadString(path);
    final data = json.decode(jsonString);
    final List<DistrictShape> shapes = [];

    final normalizedProvince = province
        .replaceAll(RegExp(r'[\s-]'), '')
        .toLowerCase();

    if (data['features'] != null) {
      for (var feature in data['features']) {
        final props = feature['properties'];
        final proEn = (props['pro_en'] ?? '').toString();

        // Normalize for match
        final normalizedProEn = proEn
            .replaceAll(RegExp(r'[\s-]'), '')
            .toLowerCase();

        if (normalizedProEn == normalizedProvince) {
          final ampEn = props['amp_en']?.toString() ?? 'Unknown';
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
          shapes.add(DistrictShape(name: ampEn, path: path));
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
    // 1. Get all photos that belong to this province from the global gallery state
    final allGalleryPhotos = _ref.read(galleryStateProvider).allPhotos;
    final normalizedProvince = provinceName
        .replaceAll(RegExp(r'[\s-]'), '')
        .toLowerCase();

    final provincePhotos = allGalleryPhotos.where((p) {
      final pProv = p.province.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
      return pProv == normalizedProvince;
    }).toList();

    final Map<String, List<PhotoItem>> photosByDistrict = {};

    // 2. Assign each photo to a district
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

      // Fuzzy match fallback for photos without location or outside boundaries
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

    // 3. For each district, select the newest photo
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
