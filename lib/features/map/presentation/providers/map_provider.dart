import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import '../widgets/thailand_map_painter.dart';

class MapState {
  final List<ProvinceShape> provinces;
  final Map<String, ui.Image?> provincePhotos;
  final bool isLoading;

  MapState({
    required this.provinces,
    required this.provincePhotos,
    required this.isLoading,
  });

  MapState copyWith({
    List<ProvinceShape>? provinces,
    Map<String, ui.Image?>? provincePhotos,
    bool? isLoading,
  }) =>
      MapState(
        provinces: provinces ?? this.provinces,
        provincePhotos: provincePhotos ?? this.provincePhotos,
        isLoading: isLoading ?? this.isLoading,
      );
}

final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  final notifier = MapNotifier(ref);
  // Trigger initial load
  notifier.loadMap();
  return notifier;
});

class MapNotifier extends StateNotifier<MapState> {
  final Ref _ref;

  MapNotifier(this._ref)
      : super(MapState(provinces: [], provincePhotos: {}, isLoading: true)) {
    _ref.listen(galleryStateProvider, (previous, next) {
      if (previous?.allPhotos != next.allPhotos) {
        _updateProvincePhotos();
      }
    });
  }

  Future<void> loadMap() async {
    state = state.copyWith(isLoading: true);
    final shapes = await loadThailandProvinces();
    state = state.copyWith(provinces: shapes, isLoading: false);
    await _updateProvincePhotos();
  }

  final Map<String, ui.Image?> _imageCache = {};

  Future<void> _updateProvincePhotos() async {
    final photosByProvince = _ref.read(galleryStateProvider).allPhotos;
    final Map<String, ui.Image?> newPhotos = {};
    
    // Group photos by province
    final Map<String, AssetEntity> provinceSelectedPhotos = {};
    for (var photo in photosByProvince) {
      if (photo.province.isNotEmpty && photo.assetEntity != null) {
        final normalizedProvince = photo.province.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
        provinceSelectedPhotos.putIfAbsent(normalizedProvince, () => photo.assetEntity!);
      }
    }

    // Load images for each province IN PARALLEL
    final List<Future<void>> futures = [];
    for (var entry in provinceSelectedPhotos.entries) {
      futures.add(() async {
        final entity = entry.value;
        // Simple cache check by ID
        if (_imageCache.containsKey(entity.id)) {
          newPhotos[entry.key] = _imageCache[entity.id];
          return;
        }

        final img = await _loadUiImage(entity);
        if (img != null) {
          _imageCache[entity.id] = img;
          newPhotos[entry.key] = img;
        }
      }());
    }

    await Future.wait(futures);
    state = state.copyWith(provincePhotos: newPhotos);
  }

  Future<ui.Image?> _loadUiImage(AssetEntity entity) async {
    // requesting small 200x200 thumbnails for map performance
    final byteData = await entity.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    if (byteData == null) return null;
    
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(byteData, (img) => completer.complete(img));
    return completer.future;
  }
}
