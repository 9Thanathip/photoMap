import 'package:flutter_riverpod/flutter_riverpod.dart';

class GallerySelectState {
  const GallerySelectState({
    this.isSelectMode = false,
    this.selectedPaths = const {},
  });

  final bool isSelectMode;
  final Set<String> selectedPaths;

  int get selectedCount => selectedPaths.length;

  GallerySelectState copyWith({
    bool? isSelectMode,
    Set<String>? selectedPaths,
  }) =>
      GallerySelectState(
        isSelectMode: isSelectMode ?? this.isSelectMode,
        selectedPaths: selectedPaths ?? this.selectedPaths,
      );
}

class GallerySelectNotifier
    extends StateNotifier<GallerySelectState> {
  GallerySelectNotifier() : super(const GallerySelectState());

  void enter() => state = const GallerySelectState(isSelectMode: true);

  void exit() => state = const GallerySelectState();

  void toggle(String path) {
    final paths = {...state.selectedPaths};
    if (paths.contains(path)) {
      paths.remove(path);
    } else {
      paths.add(path);
    }
    state = state.copyWith(selectedPaths: paths);
  }

  void selectAll(Iterable<String> paths) =>
      state = state.copyWith(selectedPaths: Set<String>.from(paths));

  void clearSelection() => state = state.copyWith(selectedPaths: {});
}

final gallerySelectProvider =
    StateNotifierProvider<GallerySelectNotifier, GallerySelectState>(
  (ref) => GallerySelectNotifier(),
);
