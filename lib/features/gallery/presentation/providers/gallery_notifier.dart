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
    required this.error,
  });

  final Map<String, List<PhotoItem>> photos;
  final String selectedProvince;
  final bool isLoading;
  final String? error;

  GalleryState copyWith({
    Map<String, List<PhotoItem>>? photos,
    String? selectedProvince,
    bool? isLoading,
    String? error,
  }) =>
      GalleryState(
        photos: photos ?? this.photos,
        selectedProvince: selectedProvince ?? this.selectedProvince,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  List<PhotoItem> getPhotosForProvince(String province) {
    if (province == 'All') {
      // Return all photos from all provinces
      final allPhotos = <PhotoItem>[];
      for (final provincePhotos in photos.values) {
        allPhotos.addAll(provincePhotos);
      }
      return allPhotos;
    }
    return photos[province] ?? [];
  }

  List<String> getProvinces() =>
      photos.keys.toList()..sort();
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
          error: null,
        )) {
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final albums = await PhotoManager.getAssetPathList(onlyAll: true);
      if (albums.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final totalCount = await albums.first.assetCountAsync;
      final assets = await albums.first.getAssetListRange(
        start: 0,
        end: totalCount,
      );

      final photos = <String, List<PhotoItem>>{};

      for (final asset in assets) {
        if (asset.type == AssetType.image) {
          final file = await asset.file;
          if (file != null) {
            const province = 'All'; // Show all photos first
            if (!photos.containsKey(province)) {
              photos[province] = <PhotoItem>[];
            }

            photos[province]!.add(PhotoItem(
              path: file.path,
              province: province,
              timestamp: asset.createDateTime,
              assetEntity: asset,
            ));
          }
        }
      }

      state = state.copyWith(photos: photos, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load photos: ${e.toString().substring(0, 50)}',
      );
    }
  }

  void selectProvince(String province) {
    state = state.copyWith(selectedProvince: province);
  }

  void addPhoto(String path, String province) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos);
    final provincePhotos = List<PhotoItem>.from(existing[province] ?? []);

    provincePhotos.add(PhotoItem(
      path: path,
      province: province,
      timestamp: DateTime.now(),
    ));

    existing[province] = provincePhotos;
    state = state.copyWith(photos: existing);
  }

  void removePhoto(String province, int index) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos);

    if (province == 'All') {
      // Get the actual photo from all photos
      final allPhotos = <PhotoItem>[];
      for (final photos in existing.values) {
        allPhotos.addAll(photos);
      }
      if (index < 0 || index >= allPhotos.length) return;

      final photoToRemove = allPhotos[index];
      // Find and remove from the original province
      for (final entry in existing.entries) {
        final idx = entry.value.indexWhere((p) => p.path == photoToRemove.path);
        if (idx != -1) {
          final photos = List<PhotoItem>.from(entry.value);
          photos.removeAt(idx);
          existing[entry.key] = photos;
          break;
        }
      }
    } else {
      final provincePhotos = List<PhotoItem>.from(existing[province] ?? []);
      if (index >= 0 && index < provincePhotos.length) {
        provincePhotos.removeAt(index);
        existing[province] = provincePhotos;
      }
    }

    state = state.copyWith(photos: existing);
  }

  void updatePhotoProvince(String oldProvince, int index, String newProvince) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos);

    // Get photos from the old province (handle "All" case)
    late List<PhotoItem> oldPhotos;
    if (oldProvince == 'All') {
      // Get the actual photo from all photos
      final allPhotos = <PhotoItem>[];
      for (final photos in existing.values) {
        allPhotos.addAll(photos);
      }
      if (index < 0 || index >= allPhotos.length) return;

      final photo = allPhotos[index];
      // Find and remove from the original province
      for (final entry in existing.entries) {
        final idx = entry.value.indexWhere((p) => p.path == photo.path);
        if (idx != -1) {
          oldPhotos = List<PhotoItem>.from(entry.value);
          oldPhotos.removeAt(idx);
          existing[entry.key] = oldPhotos;
          break;
        }
      }

      final photo2 = photo;
      final newPhotos = List<PhotoItem>.from(existing[newProvince] ?? []);
      newPhotos.add(PhotoItem(
        path: photo2.path,
        province: newProvince,
        timestamp: photo2.timestamp,
        assetEntity: photo2.assetEntity,
      ));
      existing[newProvince] = newPhotos;
    } else {
      oldPhotos = List<PhotoItem>.from(existing[oldProvince] ?? []);
      if (index >= 0 && index < oldPhotos.length) {
        final photo = oldPhotos[index];
        oldPhotos.removeAt(index);
        existing[oldProvince] = oldPhotos;

        final newPhotos = List<PhotoItem>.from(existing[newProvince] ?? []);
        newPhotos.add(PhotoItem(
          path: photo.path,
          province: newProvince,
          timestamp: photo.timestamp,
          assetEntity: photo.assetEntity,
        ));
        existing[newProvince] = newPhotos;
      }
    }

    state = state.copyWith(photos: existing);
  }

  void clearProvince(String province) {
    final existing = Map<String, List<PhotoItem>>.from(state.photos);
    existing.remove(province);
    state = state.copyWith(photos: existing);
  }

  Future<void> reloadPhotos() => _loadPhotos();
}
