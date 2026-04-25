import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'cover_photo_provider.dart';
import '../widgets/thailand_map_painter.dart';

class MapState {
  final List<ProvinceShape> provinces;
  final ui.Path? combinedPath;
  final Map<String, ui.Image?> provincePhotos;
  final Map<String, DateTime> imageLoadTimes;
  final Map<String, ui.Rect> cropRects; // normalized crop rects per province
  final bool isLoading;

  MapState({
    required this.provinces,
    this.combinedPath,
    required this.provincePhotos,
    required this.imageLoadTimes,
    this.cropRects = const {},
    required this.isLoading,
  });

  MapState copyWith({
    List<ProvinceShape>? provinces,
    ui.Path? combinedPath,
    Map<String, ui.Image?>? provincePhotos,
    Map<String, DateTime>? imageLoadTimes,
    Map<String, ui.Rect>? cropRects,
    bool? isLoading,
  }) => MapState(
    provinces: provinces ?? this.provinces,
    combinedPath: combinedPath ?? this.combinedPath,
    provincePhotos: provincePhotos ?? this.provincePhotos,
    imageLoadTimes: imageLoadTimes ?? this.imageLoadTimes,
    cropRects: cropRects ?? this.cropRects,
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
    _ref.listen(coverPhotoProvider, (previous, next) {
      if (previous?.assetIds != next.assetIds ||
          previous?.cropRects != next.cropRects) {
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
    final allPhotos = _ref.read(galleryStateProvider).allPhotos;
    final coverState = _ref.read(coverPhotoProvider);

    // Build default map: first photo per province
    final Map<String, AssetEntity> provinceSelectedPhotos = {};
    for (final photo in allPhotos) {
      if (photo.country == 'Thailand' &&
          photo.province.isNotEmpty &&
          photo.assetEntity != null) {
        final norm = photo.province
            .replaceAll(RegExp(r'[\s-]'), '')
            .toLowerCase();
        provinceSelectedPhotos.putIfAbsent(norm, () => photo.assetEntity!);
      }
    }

    // Apply cover overrides: replace with the user-selected asset
    for (final entry in coverState.assetIds.entries) {
      final norm = entry.key;
      final assetId = entry.value;
      final override = allPhotos
          .where((p) => p.assetEntity?.id == assetId)
          .firstOrNull;
      if (override?.assetEntity != null) {
        provinceSelectedPhotos[norm] = override!.assetEntity!;
        // Invalidate cached image so it reloads with the new entity
        _imageCache.remove(assetId);
      }
    }

    // Start from existing photos so we never flash empty — only update changed entries
    final updatedPhotos = Map<String, ui.Image?>.from(state.provincePhotos);

    for (final entry in provinceSelectedPhotos.entries) {
      final provinceName = entry.key;
      final entity = entry.value;
      if (_imageCache.containsKey(entity.id)) {
        updatedPhotos[provinceName] = _imageCache[entity.id];
      } else {
        // Load async without wiping existing image first
        _loadAndApplySingle(provinceName, entity);
      }
    }

    state = state.copyWith(
      provincePhotos: updatedPhotos,
      cropRects: Map.from(coverState.cropRects),
    );
  }

  Future<void> _loadAndApplySingle(
    String provinceName,
    AssetEntity entity,
  ) async {
    final img = await _loadUiImage(entity);
    if (img != null) {
      _imageCache[entity.id] = img;

      // Update state incrementally
      final updatedPhotos = Map<String, ui.Image?>.from(state.provincePhotos);
      updatedPhotos[provinceName] = img;

      final updatedLoadTimes = Map<String, DateTime>.from(state.imageLoadTimes);
      if (!updatedLoadTimes.containsKey(provinceName)) {
        updatedLoadTimes[provinceName] = DateTime.now();
      }

      state = state.copyWith(
        provincePhotos: updatedPhotos,
        imageLoadTimes: updatedLoadTimes,
      );
    }
  }

  Future<ui.Image?> _loadUiImage(AssetEntity entity) async {
    // Optimized to 250x250 for the map view.
    // This is significantly faster to decode than 400x400 and uses much less RAM.
    final byteData = await entity.thumbnailDataWithSize(
      const ThumbnailSize(250, 250),
    );
    if (byteData == null) return null;

    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(byteData, (img) => completer.complete(img));
    return completer.future;
  }
}
