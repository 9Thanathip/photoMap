import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/map/presentation/providers/map_provider.dart';

MapState _base({ui.Rect? viewBox}) => MapState(
      provinces: [],
      provincePhotos: {},
      imageLoadTimes: {},
      isLoading: false,
      viewBox: viewBox,
    );

void main() {
  group('MapState.copyWith', () {
    test('updates only the provided field', () {
      final s = _base().copyWith(isLoading: true);
      expect(s.isLoading, isTrue);
      expect(s.downloadProgress, 0.0); // untouched
    });

    test('omitted fields are preserved', () {
      final s = _base().copyWith(downloadProgress: 0.5);
      expect(s.downloadProgress, 0.5);
      expect(s.isLoading, isFalse);
    });

    test('viewBox is preserved when not passed', () {
      final box = const ui.Rect.fromLTWH(0, 0, 10, 10);
      final s = _base(viewBox: box).copyWith(isLoading: true);
      expect(s.viewBox, box);
    });

    test('viewBox can be updated', () {
      final box = const ui.Rect.fromLTWH(1, 2, 3, 4);
      final s = _base().copyWith(viewBox: box);
      expect(s.viewBox, box);
    });

    test('clearViewBox resets viewBox to null', () {
      final s = _base(viewBox: const ui.Rect.fromLTWH(0, 0, 10, 10))
          .copyWith(clearViewBox: true);
      expect(s.viewBox, isNull);
    });

    test('clearViewBox wins over a provided viewBox', () {
      final s = _base().copyWith(
        viewBox: const ui.Rect.fromLTWH(0, 0, 10, 10),
        clearViewBox: true,
      );
      expect(s.viewBox, isNull);
    });
  });
}
