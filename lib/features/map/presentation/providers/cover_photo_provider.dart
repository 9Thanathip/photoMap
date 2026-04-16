import 'dart:ui' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/features/map/data/cover_photo_repository.dart';

class CoverPhotoState {
  final Map<String, String> assetIds;   // normalizedProvince → assetId
  final Map<String, Rect> cropRects;    // normalizedProvince → normalized crop rect
  final bool loaded;

  const CoverPhotoState({
    this.assetIds = const {},
    this.cropRects = const {},
    this.loaded = false,
  });

  CoverPhotoState copyWith({
    Map<String, String>? assetIds,
    Map<String, Rect>? cropRects,
    bool? loaded,
  }) => CoverPhotoState(
    assetIds: assetIds ?? this.assetIds,
    cropRects: cropRects ?? this.cropRects,
    loaded: loaded ?? this.loaded,
  );
}

class CoverPhotoNotifier extends StateNotifier<CoverPhotoState> {
  final _repo = CoverPhotoRepository();

  CoverPhotoNotifier() : super(const CoverPhotoState()) {
    _load();
  }

  Future<void> _load() async {
    final ids = await _repo.getAllAssetIds();
    final crops = await _repo.getAllCropRects();
    state = CoverPhotoState(assetIds: ids, cropRects: crops, loaded: true);
  }

  Future<void> setCover(
      String normalizedProvince, String assetId, Rect cropRect) async {
    await _repo.setCover(normalizedProvince, assetId, cropRect);
    state = state.copyWith(
      assetIds: {...state.assetIds, normalizedProvince: assetId},
      cropRects: {...state.cropRects, normalizedProvince: cropRect},
    );
  }
}

final coverPhotoProvider =
    StateNotifierProvider<CoverPhotoNotifier, CoverPhotoState>(
  (ref) => CoverPhotoNotifier(),
);
