import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/collage/collage_transform.dart';

void main() {
  group('cover scale', () {
    test('a level photo covers on its tighter axis', () {
      // 4:3 into a square: the short side is what has to reach across.
      expect(
        cellCoverScale(const Size(4000, 3000), const Size(100, 100), 0),
        closeTo(100 / 3000, 1e-9),
      );
    });

    test('turning it demands more photo', () {
      // At 45° a square cell needs a photo √2 bigger, or the corners show
      // background — the thing that makes naive rotation look broken.
      expect(
        cellCoverScale(const Size(100, 100), const Size(100, 100), math.pi / 4),
        closeTo(math.sqrt2, 1e-9),
      );
      // Which way it was turned makes no difference.
      expect(
        cellCoverScale(const Size(100, 100), const Size(100, 100), -0.4),
        closeTo(
            cellCoverScale(const Size(100, 100), const Size(100, 100), 0.4),
            1e-9),
      );
    });
  });

  group('pan clamping', () {
    const square = Size(100, 100);

    test('at the tightest fit there is nowhere to go', () {
      final pan = clampCellPan(
        const CellTransform(offset: Offset(0.5, -0.3)),
        image: square,
        cell: square,
      );
      expect(pan, Offset.zero);
    });

    test('zooming in buys exactly the overhang', () {
      // Twice the cover scale means a photo 200 wide over a 100 cell: 50px of
      // slack each side, or half a cell width.
      final pan = clampCellPan(
        const CellTransform(scale: 2, offset: Offset(5, 0)),
        image: square,
        cell: square,
      );
      expect(pan.dx, closeTo(0.5, 1e-9));
      // Anything inside the slack is left alone.
      final small = clampCellPan(
        const CellTransform(scale: 2, offset: Offset(0.2, -0.1)),
        image: square,
        cell: square,
      );
      expect(small, const Offset(0.2, -0.1));
    });

    test('a turned photo is clipped along its own axes', () {
      // A 4:1 strip stood on end by a quarter turn: it overhangs the cell
      // vertically on screen and not at all horizontally. Clipping x and y as
      // they come would have it backwards.
      const strip = Size(400, 100);
      const turned = CellTransform(rotation: math.pi / 2);

      final across = clampCellPan(
        turned.copyWith(offset: const Offset(1, 0)),
        image: strip,
        cell: square,
      );
      expect(across.dx, closeTo(0, 1e-9));

      final along = clampCellPan(
        turned.copyWith(offset: const Offset(0, 1)),
        image: strip,
        cell: square,
      );
      expect(along.dy, closeTo(1, 1e-9));
    });

    test('the same framing clamps the same at any cell size', () {
      // What makes the export match the preview: the user frames against a
      // ~120pt cell and the PNG is rendered into a ~1200px one.
      const t = CellTransform(scale: 1.5, rotation: 0.3, offset: Offset(2, -2));
      const image = Size(1280, 960);
      final small = clampCellPan(t, image: image, cell: const Size(100, 130));
      final large = clampCellPan(t, image: image, cell: const Size(1000, 1300));
      expect(small.dx, closeTo(large.dx, 1e-9));
      expect(small.dy, closeTo(large.dy, 1e-9));
    });

    test('a degenerate cell or photo pans nowhere instead of blowing up', () {
      const t = CellTransform(offset: Offset(1, 1));
      expect(clampCellPan(t, image: Size.zero, cell: square), Offset.zero);
      expect(clampCellPan(t, image: square, cell: Size.zero), Offset.zero);
    });
  });

  test('an untouched cell reads as identity', () {
    expect(const CellTransform().isIdentity, isTrue);
    expect(const CellTransform(rotation: 0.01).isIdentity, isFalse);
    expect(const CellTransform(scale: 1.2).isIdentity, isFalse);
    expect(
      const CellTransform().copyWith(offset: const Offset(0.1, 0)).isIdentity,
      isFalse,
    );
  });
}
