import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoItem {
  const PhotoItem({
    required this.path,
    required this.province,
    required this.timestamp,
    this.assetEntity,
  });

  final String path;
  final String province;
  final DateTime timestamp;
  final AssetEntity? assetEntity;
}

class GalleryState {
  const GalleryState({
    required this.photos,
    required this.selectedProvince,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.error,
  });

  final Map<String, List<PhotoItem>> photos;
  final String selectedProvince;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  GalleryState copyWith({
    Map<String, List<PhotoItem>>? photos,
    String? selectedProvince,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) =>
      GalleryState(
        photos: photos ?? this.photos,
        selectedProvince: selectedProvince ?? this.selectedProvince,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );

  List<PhotoItem> getPhotosForProvince(String province) {
    if (province == 'All') {
      final allPhotos = <PhotoItem>[];
      for (final provincePhotos in photos.values) {
        allPhotos.addAll(provincePhotos);
      }
      return allPhotos;
    }
    return photos[province] ?? [];
  }

  List<String> getProvinces() => photos.keys.toList()..sort();
}

final galleryStateProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  return GalleryNotifier();
});

class GalleryNotifier extends StateNotifier<GalleryState> {
  GalleryNotifier()
      : super(const GalleryState(
          photos: {},
          selectedProvince: 'All',
          isLoading: false,
          isLoadingMore: false,
          hasMore: false,
          error: null,
        )) {
    Future.delayed(const Duration(milliseconds: 300), _loadFirstPage);
  }

  static const _pageSize = 100;
  int _loadedCount = 0;
  int _totalCount = 0;
  AssetPathEntity? _album;

  Future<void> _loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final albums = await PhotoManager.getAssetPathList(onlyAll: true);
      if (albums.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      _album = albums.first;
      _totalCount = await _album!.assetCountAsync;
      _loadedCount = 0;

      final end = _totalCount.clamp(0, _pageSize);
      final assets = await _album!.getAssetListRange(start: 0, end: end);
      _loadedCount = end;

      final photos = <String, List<PhotoItem>>{};
      for (final asset in assets) {
        if (asset.type == AssetType.image) {
          const province = 'All';
          photos.putIfAbsent(province, () => []);
          photos[province]!.add(PhotoItem(
            path: asset.id,
            province: province,
            timestamp: asset.createDateTime,
            assetEntity: asset,
          ));
        }
      }

      state = state.copyWith(
        photos: photos,
        isLoading: false,
        hasMore: _loadedCount < _totalCount,
      );
    } catch (e) {
      final msg = e.toString().contains('Permission')
          ? 'Photo permission denied. Please allow access in Settings.'
          : 'Failed to load photos: ${e.toString().replaceFirst('Exception: ', '')}';
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _album == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final start = _loadedCount;
      final end = (_loadedCount + _pageSize).clamp(0, _totalCount);
      final assets = await _album!.getAssetListRange(start: start, end: end);
      _loadedCount = end;

      final existing = Map<String, List<PhotoItem>>.from(state.photos);
      for (final asset in assets) {
        if (asset.type == AssetType.image) {
          const province = 'All';
          existing.putIfAbsent(province, () => []);
          existing[province]!.add(PhotoItem(
            path: asset.id,
            province: province,
            timestamp: asset.createDateTime,
            assetEntity: asset,
          ));
        }
      }

      state = state.copyWith(
        photos: existing,
        isLoadingMore: false,
        hasMore: _loadedCount < _totalCount,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void selectProvince(String province) {
    state = state.copyWith(selectedProvince: province);
  }

  void addPhoto(String path, String province) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos);
    final list = List<PhotoItem>.from(existing[province] ?? []);
    list.insert(
      0,
      PhotoItem(path: path, province: province, timestamp: DateTime.now()),
    );
    existing[province] = list;
    state = state.copyWith(photos: existing);
  }

  void removePhoto(String province, int index) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos);

    if (province == 'All') {
      final allPhotos = <PhotoItem>[];
      for (final p in existing.values) { allPhotos.addAll(p); }
      if (index < 0 || index >= allPhotos.length) return;

      final target = allPhotos[index];
      for (final entry in existing.entries) {
        final i = entry.value.indexWhere((p) => p.path == target.path);
        if (i != -1) {
          final list = List<PhotoItem>.from(entry.value)..removeAt(i);
          existing[entry.key] = list;
          break;
        }
      }
    } else {
      final list = List<PhotoItem>.from(existing[province] ?? []);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        existing[province] = list;
      }
    }

    state = state.copyWith(photos: existing);
  }

  void updatePhotoProvince(String oldProvince, int index, String newProvince) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos);

    PhotoItem? photo;

    if (oldProvince == 'All') {
      final allPhotos = <PhotoItem>[];
      for (final p in existing.values) { allPhotos.addAll(p); }
      if (index < 0 || index >= allPhotos.length) return;
      photo = allPhotos[index];

      for (final entry in existing.entries) {
        final i = entry.value.indexWhere((p) => p.path == photo!.path);
        if (i != -1) {
          final list = List<PhotoItem>.from(entry.value)..removeAt(i);
          existing[entry.key] = list;
          break;
        }
      }
    } else {
      final list = List<PhotoItem>.from(existing[oldProvince] ?? []);
      if (index < 0 || index >= list.length) return;
      photo = list[index];
      list.removeAt(index);
      existing[oldProvince] = list;
    }

    final newList = List<PhotoItem>.from(existing[newProvince] ?? []);
    newList.add(PhotoItem(
      path: photo.path,
      province: newProvince,
      timestamp: photo.timestamp,
      assetEntity: photo.assetEntity,
    ));
    existing[newProvince] = newList;
    state = state.copyWith(photos: existing);
  }

  void clearProvince(String province) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos)
      ..remove(province);
    state = state.copyWith(photos: existing);
  }

  Future<void> reloadPhotos() => _loadFirstPage();
}
