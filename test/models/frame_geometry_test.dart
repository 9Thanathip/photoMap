import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/frame/frame_painter.dart';
import 'package:photo_map/features/gallery/presentation/widgets/frame/frame_style.dart';

void main() {
  const photo = Size(400, 300); // landscape, short edge = 300

  group('computeFrameGeometry.minimal', () {
    test('canvas equals the photo, no padding', () {
      final g = computeFrameGeometry(FrameStyle.minimal, photo);
      expect(g.canvasSize, photo);
      expect(g.photoRect, const Rect.fromLTWH(0, 0, 400, 300));
      expect(g.unit, 300); // short edge
    });
  });

  group('computeFrameGeometry.bottomBar', () {
    test('adds a bar of 15% of the short edge below the photo', () {
      final g = computeFrameGeometry(FrameStyle.bottomBar, photo);
      // barH = 300 * 0.15 = 45
      expect(g.canvasSize, const Size(400, 345));
      expect(g.photoRect, const Rect.fromLTWH(0, 0, 400, 300));
    });

    test('frameScale thickens the bar', () {
      final g = computeFrameGeometry(FrameStyle.bottomBar, photo, frameScale: 2);
      // barH = 300 * 0.15 * 2 = 90
      expect(g.canvasSize.height, 390);
    });
  });

  group('computeFrameGeometry.fullBorder', () {
    test('adds even margins with a wider bottom', () {
      final g = computeFrameGeometry(FrameStyle.fullBorder, photo);
      // margin = 300*0.05 = 15, bottom = 300*0.20 = 60
      expect(g.canvasSize, const Size(430, 375)); // 400+30, 300+15+60
      expect(g.photoRect, const Rect.fromLTWH(15, 15, 400, 300));
    });
  });

  test('unit follows the short edge for a portrait photo', () {
    final g = computeFrameGeometry(FrameStyle.minimal, const Size(300, 500));
    expect(g.unit, 300);
  });
}
