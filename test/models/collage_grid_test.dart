import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/collage/collage_painter.dart';
import 'package:photo_map/features/gallery/presentation/widgets/collage/collage_ratio.dart';

void main() {
  group('CollageGrid.count', () {
    test('rows * cols', () {
      expect(const CollageGrid(2, 3).count, 6);
      expect(const CollageGrid(1, 1).count, 1);
      expect(const CollageGrid(5, 7).count, 35);
    });
  });

  group('CollageGrid.cellRect', () {
    const area = Rect.fromLTWH(0, 0, 100, 100);

    test('no gap: cells tile the area edge-to-edge', () {
      const grid = CollageGrid(2, 2);
      expect(grid.cellRect(0, area, 0), const Rect.fromLTWH(0, 0, 50, 50));
      expect(grid.cellRect(1, area, 0), const Rect.fromLTWH(50, 0, 50, 50));
      expect(grid.cellRect(2, area, 0), const Rect.fromLTWH(0, 50, 50, 50));
      expect(grid.cellRect(3, area, 0), const Rect.fromLTWH(50, 50, 50, 50));
    });

    test('gap is applied around and between cells', () {
      const grid = CollageGrid(2, 2);
      // cellW = (100 - 10*(2+1)) / 2 = 35
      final c0 = grid.cellRect(0, area, 10);
      expect(c0, const Rect.fromLTWH(10, 10, 35, 35));
      final c3 = grid.cellRect(3, area, 10);
      // left/top = 10 + 1*(35+10) = 55
      expect(c3, const Rect.fromLTWH(55, 55, 35, 35));
    });

    test('index maps to row-major position', () {
      const grid = CollageGrid(2, 3); // 2 rows, 3 cols
      // index 4 -> row 1, col 1
      final cell = grid.cellRect(4, area, 0);
      expect(cell.left, closeTo(100 / 3, 1e-9));
      expect(cell.top, closeTo(50, 1e-9));
    });
  });

  group('CollageGrid.indexAt', () {
    const area = Rect.fromLTWH(0, 0, 100, 100);
    const grid = CollageGrid(2, 2);

    test('point inside a cell returns its index', () {
      expect(grid.indexAt(const Offset(25, 25), area, 0), 0);
      expect(grid.indexAt(const Offset(75, 75), area, 0), 3);
    });

    test('point in a gap returns null', () {
      // gap band around x=... with gap 10 the first gap is x in [0,10)
      expect(grid.indexAt(const Offset(5, 5), area, 10), isNull);
    });

    test('point outside the area returns null', () {
      expect(grid.indexAt(const Offset(-1, -1), area, 0), isNull);
      expect(grid.indexAt(const Offset(200, 200), area, 0), isNull);
    });
  });

  group('CollageRatio', () {
    test('value is width / height', () {
      expect(CollageRatio.square.value, 1.0);
      expect(CollageRatio.portrait45.value, closeTo(0.8, 1e-9));
      expect(CollageRatio.landscape169.value, closeTo(16 / 9, 1e-9));
    });

    test('label is w:h', () {
      expect(CollageRatio.portrait45.label, '4:5');
      expect(CollageRatio.story.label, '9:16');
    });
  });
}
