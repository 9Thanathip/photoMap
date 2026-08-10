import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photo_map/common_widgets/photo_grid.dart';

/// How dense the photo grids are.
///
/// App-wide rather than per-screen on purpose: a tile's decode size follows
/// the column count, and one size across every grid means one cached decode
/// per photo instead of one per screen.
class GalleryGridState {
  const GalleryGridState({this.columns = kPhotoGridColumns});

  final int columns;

  GalleryGridState copyWith({int? columns}) =>
      GalleryGridState(columns: columns ?? this.columns);
}

class GalleryGridNotifier extends StateNotifier<GalleryGridState> {
  GalleryGridNotifier() : super(const GalleryGridState());

  void setColumns(int columns) {
    if (!kGridColumnSteps.contains(columns) || columns == state.columns) {
      return;
    }
    state = state.copyWith(columns: columns);
  }
}

final galleryGridProvider =
    StateNotifierProvider<GalleryGridNotifier, GalleryGridState>(
  (ref) => GalleryGridNotifier(),
);
