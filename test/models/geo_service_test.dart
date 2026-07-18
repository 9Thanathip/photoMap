import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/core/services/geo_service.dart';

/// Builds a square province covering [lngMin..lngMax] × [latMin..latMax].
/// Mirrors [GeoService]'s internal (lng, -lat) coordinate space.
ProvinceBoundary _square(
  String name, {
  required double lngMin,
  required double lngMax,
  required double latMin,
  required double latMax,
}) {
  final ring = <Offset>[
    Offset(lngMin, -latMin),
    Offset(lngMax, -latMin),
    Offset(lngMax, -latMax),
    Offset(lngMin, -latMax),
    Offset(lngMin, -latMin),
  ];
  final path = Path()..addRect(Rect.fromLTRB(lngMin, -latMax, lngMax, -latMin));
  final centroid = Offset((lngMin + lngMax) / 2, -(latMin + latMax) / 2);
  return ProvinceBoundary(
    name: name,
    path: path,
    rings: [ring],
    centroid: centroid,
  );
}

void main() {
  // A 1°×1° square around (lat 13-14, lng 100-101).
  final geo = GeoService.withBoundaries([
    _square('bangkok', lngMin: 100, lngMax: 101, latMin: 13, latMax: 14),
  ]);

  group('GeoService.getProvince — point in polygon', () {
    test('point inside returns the province', () {
      expect(geo.getProvince(13.5, 100.5), 'bangkok');
    });

    test('point on the far side of the world returns null', () {
      expect(geo.getProvince(0, 0), isNull);
      expect(geo.getProvince(-40, -70), isNull);
    });
  });

  group('GeoService.getProvince — nearest fallback (~50km)', () {
    test('just outside the edge still resolves via nearest boundary', () {
      // 0.2° east of the lng=101 edge, within the 0.45° threshold.
      expect(geo.getProvince(13.5, 101.2), 'bangkok');
    });

    test('beyond the fallback threshold returns null', () {
      // ~1° away, well past 0.45°.
      expect(geo.getProvince(13.5, 102.5), isNull);
    });
  });

  test('uninitialized service returns null', () {
    expect(GeoService().getProvince(13.5, 100.5), isNull);
  });
}
