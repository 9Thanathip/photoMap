import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/editor/local_adjust.dart';
import 'package:photo_map/features/gallery/utils/color_matrix_utils.dart';

const Rect _rect = Rect.fromLTWH(0, 0, 200, 200);

/// Rasterizes a mask's coverage and returns the alpha (0..255) at [x],[y].
Future<int> _alphaAt(LocalMask mask, int x, int y) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, _rect);
  mask.paintMaskAlpha(canvas, _rect, Paint());
  final image = await recorder.endRecording().toImage(200, 200);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  image.dispose();
  return bytes[(y * 200 + x) * 4 + 3];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // rx = 60px, ry = 20px around (100, 100); feather 0 keeps the edge hard so
  // "inside" and "outside" are unambiguous.
  const ellipse = LocalMask(
    id: 1,
    type: LocalMaskType.radial,
    radius: 0.3,
    radiusY: 0.1,
    feather: 0.0,
    exposure: 0.5,
  );

  test('radial mask covers an ellipse, not a circle', () async {
    expect(await _alphaAt(ellipse, 150, 100), greaterThan(200),
        reason: '50px out along the 60px x-axis is inside');
    expect(await _alphaAt(ellipse, 100, 140), lessThan(40),
        reason: '40px out along the 20px y-axis is outside');
  });

  test('rotating a radial mask by a quarter turn swaps its axes', () async {
    final turned = ellipse.copyWith(angle: math.pi / 2);
    expect(await _alphaAt(turned, 150, 100), lessThan(40));
    expect(await _alphaAt(turned, 100, 140), greaterThan(200));
  });

  group('radial hit-testing', () {
    // 100px circle centred in a 400x400 frame.
    const mask = LocalMask(id: 1, type: LocalMaskType.radial);
    const rect = Rect.fromLTWH(0, 0, 400, 400);

    test('axis handles resize a single axis', () {
      expect(radialHandleAt(mask, const Offset(300, 200), rect),
          MaskHandle.resizeX);
      expect(radialHandleAt(mask, const Offset(100, 200), rect),
          MaskHandle.resizeX);
      expect(radialHandleAt(mask, const Offset(200, 300), rect),
          MaskHandle.resizeY);
    });

    test('the rest of the ring resizes both axes', () {
      final diagonal = Offset(200 + 100 / math.sqrt2, 200 + 100 / math.sqrt2);
      expect(radialHandleAt(mask, diagonal, rect), MaskHandle.resize);
    });

    test('the rotate handle wins over the axis handle behind it', () {
      final h = RadialHandles(mask, rect);
      expect(radialHandleAt(mask, h.rotateHandle, rect), MaskHandle.rotate);
      // ...and the resize handle it floats past is still reachable.
      expect(radialHandleAt(mask, h.bottom, rect), MaskHandle.resizeY);
    });

    test('everywhere else moves the mask', () {
      expect(
          radialHandleAt(mask, const Offset(200, 200), rect), MaskHandle.move);
      expect(radialHandleAt(mask, const Offset(20, 20), rect), MaskHandle.move);
    });
  });

  group('rotate handle', () {
    // Shortest angular difference, so π and -π compare equal.
    double wrap(double a) {
      var x = (a + math.pi) % (2 * math.pi);
      if (x < 0) x += 2 * math.pi;
      return x - math.pi;
    }

    test('its direction round-trips to the stored angle', () {
      const rect = Rect.fromLTWH(0, 0, 400, 400);
      for (final angle in [0.0, 0.7, -1.2, math.pi, 2.5]) {
        final mask = LocalMask(
          id: 1,
          type: LocalMaskType.radial,
          radius: 0.3,
          radiusY: 0.2,
          angle: angle,
        );
        final h = RadialHandles(mask, rect);
        final v = h.rotateHandle - h.center;
        // This is exactly what the drag does — if it doesn't recover [angle],
        // grabbing the handle snaps the mask somewhere else.
        final recovered = math.atan2(v.dy, v.dx) - h.rotateTurn;
        expect(wrap(recovered - angle).abs(), lessThan(0.01),
            reason: 'angle $angle came back as $recovered');
      }
    });

    test('sits above the mask when there is room', () {
      const rect = Rect.fromLTWH(0, 0, 400, 400);
      const mask = LocalMask(
        id: 1,
        type: LocalMaskType.radial,
        radius: 0.3,
        radiusY: 0.2,
      );
      final h = RadialHandles(mask, rect);
      expect(h.rotateHandle.dy, lessThan(h.center.dy));
    });

    test('flips to a side that stays on the photo', () {
      // Wide crop: below and above the ellipse both fall outside.
      const rect = Rect.fromLTWH(0, 0, 400, 120);
      const mask = LocalMask(
        id: 1,
        type: LocalMaskType.radial,
        radius: 0.4,
        radiusY: 0.4,
      );
      final h = RadialHandles(mask, rect);
      expect(h.rotateTurn, 0.0, reason: 'should have moved to the x axis');
      expect(rect.contains(h.rotateHandle), isTrue);
      expect(radialHandleAt(mask, h.rotateHandle, rect), MaskHandle.rotate);

      final v = h.rotateHandle - h.center;
      expect(wrap(math.atan2(v.dy, v.dx) - h.rotateTurn).abs(), lessThan(0.01));
    });

    test('linear rides the gradient axis, not the perpendicular', () {
      const rect = Rect.fromLTWH(0, 0, 400, 400);
      const mask = LocalMask(id: 1, type: LocalMaskType.linear);
      final h = LinearHandles(mask, rect);
      expect(h.rotateHandle.dx, closeTo(h.mid.dx, 0.01),
          reason: 'must stay on the axis through the midpoint');
      expect(h.rotateHandle.dy, lessThan(h.mid.dy), reason: 'and sit above it');
      // Its stem hangs off the outer line, not all the way back to the middle.
      expect((h.rotateHandle - h.rotateAnchor).distance,
          closeTo(kMaskRotateGap, 0.01));
      // Clear of the outer lines, so grabbing them still works.
      expect(linearHandleAt(mask, h.start, rect), MaskHandle.start);
      expect(linearHandleAt(mask, h.rotateHandle, rect), MaskHandle.rotate);
    });

    test('linear flips its side when the preferred end is off-frame', () {
      const rect = Rect.fromLTWH(0, 0, 400, 400);
      const mask = LocalMask(
        id: 1,
        type: LocalMaskType.linear,
        linearStart: Offset(0.5, 0.02),
        linearEnd: Offset(0.5, 0.3),
      );
      final h = LinearHandles(mask, rect);
      expect(h.rotateSide, 1.0, reason: 'above the mask falls off the top');
      expect(rect.contains(h.rotateHandle), isTrue);
      expect(linearHandleAt(mask, h.rotateHandle, rect), MaskHandle.rotate);
    });
  });

  test('the inner ellipse is the feather handle', () {
    const mask = LocalMask(id: 1, type: LocalMaskType.radial); // feather 0.5
    const rect = Rect.fromLTWH(0, 0, 400, 400);
    // r=100, so the fade starts at r=50.
    expect(
        radialHandleAt(mask, const Offset(250, 200), rect), MaskHandle.feather);
  });

  group('maskContains picks the mask under a tap', () {
    test('radial', () {
      const mask = LocalMask(id: 1, type: LocalMaskType.radial);
      const rect = Rect.fromLTWH(0, 0, 400, 400);
      expect(maskContains(mask, const Offset(240, 200), rect), isTrue);
      expect(maskContains(mask, const Offset(340, 200), rect), isFalse);
    });

    test('linear covers everything up to the end line', () {
      const mask = LocalMask(id: 1, type: LocalMaskType.linear);
      expect(maskContains(mask, const Offset(100, 20), _rect), isTrue,
          reason: 'coverage runs on past the start line');
      expect(maskContains(mask, const Offset(100, 180), _rect), isFalse);
    });

    test('brush follows the strokes, ignoring erase ones', () {
      const stroke = BrushStroke(points: [Offset(0.5, 0.5)], radius: 0.1);
      const painted =
          LocalMask(id: 1, type: LocalMaskType.brush, strokes: [stroke]);
      expect(maskContains(painted, const Offset(105, 105), _rect), isTrue);
      expect(maskContains(painted, const Offset(150, 100), _rect), isFalse);

      final erased = painted.copyWith(strokes: [stroke.copyWith(erase: true)]);
      expect(maskContains(erased, const Offset(105, 105), _rect), isFalse);
    });
  });

  test('brush flow scales the coverage it lays down', () async {
    const full = LocalMask(
      id: 1,
      type: LocalMaskType.brush,
      strokes: [
        BrushStroke(points: [Offset(0.5, 0.5)], radius: 0.1, feather: 0)
      ],
    );
    final half = full.copyWith(
      strokes: [full.strokes.first.copyWith(flow: 0.5)],
    );
    final a = await _alphaAt(full, 100, 100);
    final b = await _alphaAt(half, 100, 100);
    expect(a, greaterThan(240));
    expect(b, inInclusiveRange(100, 160));
  });

  test('every local tonal channel reaches the matrix', () {
    const neutral = LocalMask(id: 1, type: LocalMaskType.radial);
    expect(neutral.hasEffect, isFalse);
    for (final mask in [
      neutral.copyWith(exposure: 0.5),
      neutral.copyWith(contrast: 0.5),
      neutral.copyWith(shadows: 0.5),
      neutral.copyWith(highlights: 0.5),
      neutral.copyWith(saturation: 0.5),
      neutral.copyWith(warmth: 0.5),
      neutral.copyWith(tint: 0.5),
    ]) {
      expect(mask.hasEffect, isTrue);
      expect(mask.matrix.matrix, isNot(ColorMatrix.identity.matrix));
    }
    // Amount 0 mutes the mask entirely.
    expect(neutral.copyWith(exposure: 0.5, amount: 0).hasEffect, isFalse);
  });

  group('linear hit-testing', () {
    const mask = LocalMask(id: 1, type: LocalMaskType.linear);
    const rect = Rect.fromLTWH(0, 0, 400, 400);

    test('endpoints, rotate handle and move', () {
      final h = LinearHandles(mask, rect);
      expect(linearHandleAt(mask, h.start, rect), MaskHandle.start);
      expect(linearHandleAt(mask, h.end, rect), MaskHandle.end);
      expect(linearHandleAt(mask, h.rotateHandle, rect), MaskHandle.rotate);
      expect(linearHandleAt(mask, h.mid, rect), MaskHandle.move);
    });

    test('each of the three lines is grabbable anywhere along it', () {
      // Default gradient runs top to bottom through the middle, so the lines
      // are horizontal at y = 100 / 200 / 300. Grab them way off to the side.
      expect(linearHandleAt(mask, const Offset(30, 100), rect),
          MaskHandle.start);
      expect(linearHandleAt(mask, const Offset(370, 300), rect),
          MaskHandle.end);
      expect(
          linearHandleAt(mask, const Offset(30, 200), rect), MaskHandle.move);
    });
  });
}
