import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/core/services/boundary_export.dart';

void main() {
  group('export resolution', () {
    test('never renders below the screen it was captured from', () {
      // The bug this replaces: a flat pixelRatio of 2 on a 3x phone wrote the
      // map at two thirds of what was on screen, and Photos scaled it back up.
      for (final dpr in [1.0, 2.0, 3.0]) {
        final ratio = exportPixelRatio(
          devicePixelRatio: dpr,
          longestSide: 4000, // already huge, so the floor is what decides
        );
        expect(ratio, greaterThanOrEqualTo(dpr), reason: 'at ${dpr}x');
      }
    });

    test('a phone-sized map is oversampled to something worth keeping', () {
      // A full-height map on a 3x phone is about 600pt down its long edge:
      // 1800px at the device ratio, which is fine on screen and soft the
      // moment it is pinched into in Photos.
      const longest = 600.0;
      final ratio = exportPixelRatio(
        devicePixelRatio: 3,
        longestSide: longest,
      );
      expect(longest * ratio, greaterThanOrEqualTo(kExportLongEdge));
      expect(ratio, greaterThan(3));
      // And the cap has to leave room for that, or the target is unreachable
      // at any realistic size.
      expect(kExportLongEdge / longest, lessThanOrEqualTo(kExportMaxScale));
    });

    test('a surface that is already big enough is not blown up further', () {
      final ratio = exportPixelRatio(
        devicePixelRatio: 2,
        longestSide: 2000,
      );
      expect(ratio, 2);
    });

    test('the scale is capped', () {
      // Without a ceiling a tiny boundary would ask for a buffer measured in
      // hundreds of megabytes.
      final ratio = exportPixelRatio(devicePixelRatio: 3, longestSide: 10);
      expect(ratio, kExportMaxScale);
    });

    test('a zero-sized boundary falls back to the device ratio', () {
      expect(exportPixelRatio(devicePixelRatio: 3, longestSide: 0), 3);
    });
  });
}
