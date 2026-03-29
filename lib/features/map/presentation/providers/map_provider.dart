import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import '../widgets/thailand_map_painter.dart';

class MapState {
  final List<ProvinceShape> provinces;
  final ui.Path? combinedPath;
  final Map<String, ui.Image?> provincePhotos;
  final Map<String, DateTime> imageLoadTimes; // Track when images were loaded
  final bool isLoading;

  MapState({
    required this.provinces,
    this.combinedPath,
    required this.provincePhotos,
    required this.imageLoadTimes,
    required this.isLoading,
  });

  MapState copyWith({
    List<ProvinceShape>? provinces,
    ui.Path? combinedPath,
    Map<String, ui.Image?>? provincePhotos,
    Map<String, DateTime>? imageLoadTimes,
    bool? isLoading,
  }) => MapState(
    provinces: provinces ?? this.provinces,
    combinedPath: combinedPath ?? this.combinedPath,
    provincePhotos: provincePhotos ?? this.provincePhotos,
    imageLoadTimes: imageLoadTimes ?? this.imageLoadTimes,
    isLoading: isLoading ?? this.isLoading,
  );
}

final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  final notifier = MapNotifier(ref);
  notifier.loadMap();
  return notifier;
});

class MapNotifier extends StateNotifier<MapState> {
  final Ref _ref;

  MapNotifier(this._ref)
    : super(
        MapState(
          provinces: [],
          provincePhotos: {},
          imageLoadTimes: {},
          isLoading: true,
        ),
      ) {
    _ref.listen(galleryStateProvider, (previous, next) {
      if (previous?.allPhotos != next.allPhotos) {
        _updateProvincePhotos();
      }
    });
  }

  Future<void> loadMap() async {
    state = state.copyWith(isLoading: true);
    final shapes = await loadThailandProvinces();

    // Pre-calculate combined path once to avoid expensive per-frame path creation
    final combined = ui.Path();
    for (final s in shapes) {
      combined.addPath(s.path, ui.Offset.zero);
    }

    state = state.copyWith(
      provinces: shapes,
      combinedPath: combined,
      isLoading: false,
    );
    await _updateProvincePhotos();
  }

  final Map<String, ui.Image?> _imageCache = {};

  Future<void> _updateProvincePhotos() async {
    final photosByProvince = _ref.read(galleryStateProvider).allPhotos;
    final Map<String, ui.Image?> newPhotos = {};
    final newLoadTimes = Map<String, DateTime>.from(state.imageLoadTimes);

    // Group photos by province
    final Map<String, AssetEntity> provinceSelectedPhotos = {};
    for (var photo in photosByProvince) {
      if (photo.province.isNotEmpty && photo.assetEntity != null) {
        final normalizedProvince = photo.province
            .replaceAll(RegExp(r'[\s-]'), '')
            .toLowerCase();
        provinceSelectedPhotos.putIfAbsent(
          normalizedProvince,
          () => photo.assetEntity!,
        );
      }
    }

    // Load images for each province IN PARALLEL
    final List<Future<void>> futures = [];
    for (var entry in provinceSelectedPhotos.entries) {
      futures.add(() async {
        final provinceName = entry.key;
        final entity = entry.value;

        // Cache hit
        if (_imageCache.containsKey(entity.id)) {
          newPhotos[provinceName] = _imageCache[entity.id];
          return;
        }

        final img = await _loadUiImage(entity);
        if (img != null) {
          _imageCache[entity.id] = img;
          newPhotos[provinceName] = img;
        }
      }());
    }

    await Future.wait(futures);

    // Captured AFTER loading so the fade starts exactly when they are rendered
    final now = DateTime.now();
    for (var provinceName in newPhotos.keys) {
      if (!state.provincePhotos.containsKey(provinceName)) {
        newLoadTimes[provinceName] = now;
      }
    }

    state = state.copyWith(
      provincePhotos: newPhotos,
      imageLoadTimes: newLoadTimes,
    );
  }

  Future<ui.Image?> _loadUiImage(AssetEntity entity) async {
    // 400x400 is the safest point for stability on Android.
    // 768x768 uses ~180MB for 77 images, which exceeds many device limits when zooming.
    final byteData = await entity.thumbnailDataWithSize(
      const ThumbnailSize(400, 400),
    );
    if (byteData == null) return null;

    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(byteData, (img) => completer.complete(img));
    return completer.future;
  }
}
