import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Maximum distance in degrees before we give up on nearest-province fallback.
/// 0.45° ≈ 50 km — covers piers, bridges, boats close to shore.
const _kMaxFallbackDeg = 0.45;

class ProvinceBoundary {
  final String name;
  final Path path;

  /// All polygon rings as flat lists of (lng, -lat) Offsets.
  /// Used by the nearest-boundary fallback when point-in-polygon fails.
  final List<List<Offset>> rings;

  /// Centroid in (lng, -lat) space — used to pre-sort provinces by rough
  /// proximity so we can bail out of the distance search early.
  final Offset centroid;

  ProvinceBoundary({
    required this.name,
    required this.path,
    required this.rings,
    required this.centroid,
  });
}

class GeoService {
  List<ProvinceBoundary>? _boundaries;

  /// Loads the GeoJSON file and parses provinces into paths + raw rings.
  Future<void> initialize() async {
    if (_boundaries != null) return;

    final String jsonString =
        await rootBundle.loadString('assets/data/thailand.json');
    final data = json.decode(jsonString);
    final List<ProvinceBoundary> boundaries = [];

    if (data['features'] != null) {
      for (var feature in data['features']) {
        final rawName = feature['properties']['CHA_NE'] ??
            feature['properties']['name'] ??
            feature['properties']['NAME_1'] ??
            'Unknown';

        final normalizedName =
            rawName.toString().replaceAll(RegExp(r'[\s-]'), '').toLowerCase();

        final geometry = feature['geometry'];
        final type = geometry['type'];
        final coordinates = geometry['coordinates'];

        final path = Path();
        final List<List<Offset>> allRings = [];

        if (type == 'Polygon') {
          final ring = _ringToOffsets(coordinates[0]);
          _addRingToPath(path, ring);
          allRings.add(ring);
        } else if (type == 'MultiPolygon') {
          for (var polygon in coordinates) {
            final ring = _ringToOffsets(polygon[0]);
            _addRingToPath(path, ring);
            allRings.add(ring);
          }
        }

        final centroid = _computeCentroid(allRings);
        boundaries
            .add(ProvinceBoundary(name: normalizedName, path: path, rings: allRings, centroid: centroid));
      }
    }
    _boundaries = boundaries;
  }

  // ── Path helpers ──────────────────────────────────────────────────────────

  List<Offset> _ringToOffsets(List coords) {
    return [
      for (var pt in coords)
        Offset((pt[0] as num).toDouble(), -(pt[1] as num).toDouble())
    ];
  }

  void _addRingToPath(Path path, List<Offset> ring) {
    if (ring.isEmpty) return;
    path.moveTo(ring[0].dx, ring[0].dy);
    for (var i = 1; i < ring.length; i++) {
      path.lineTo(ring[i].dx, ring[i].dy);
    }
    path.close();
  }

  Offset _computeCentroid(List<List<Offset>> rings) {
    double sumX = 0, sumY = 0;
    int count = 0;
    for (final ring in rings) {
      for (final pt in ring) {
        sumX += pt.dx;
        sumY += pt.dy;
        count++;
      }
    }
    if (count == 0) return Offset.zero;
    return Offset(sumX / count, sumY / count);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the normalized province name for a given lat/lng.
  ///
  /// First tries an exact point-in-polygon check. If that fails (e.g. the
  /// photo was taken on a pier, boat, or just offshore), falls back to the
  /// nearest province boundary within [_kMaxFallbackDeg] degrees (~50 km).
  String? getProvince(double lat, double lng) {
    if (_boundaries == null) return null;

    final point = Offset(lng, -lat);

    // ── Pass 1: exact point-in-polygon ────────────────────────────────────
    for (final boundary in _boundaries!) {
      if (boundary.path.contains(point)) return boundary.name;
    }

    // ── Pass 2: nearest boundary fallback ────────────────────────────────
    // Sort provinces by centroid distance first so we stop searching early.
    final sorted = _boundaries!.toList()
      ..sort((a, b) => _dist2(a.centroid, point).compareTo(_dist2(b.centroid, point)));

    String? nearest;
    double minDist = double.infinity;

    for (final boundary in sorted) {
      // If the centroid is already farther than our current best + threshold,
      // all remaining provinces will be even farther — bail out.
      final centroidDist = _dist(boundary.centroid, point);
      if (centroidDist - minDist > _kMaxFallbackDeg * 3) break;

      final d = _distToRings(point, boundary.rings);
      if (d < minDist) {
        minDist = d;
        nearest = boundary.name;
      }
    }

    return (minDist <= _kMaxFallbackDeg) ? nearest : null;
  }

  // ── Distance helpers ──────────────────────────────────────────────────────

  double _dist2(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
  }

  double _dist(Offset a, Offset b) => math.sqrt(_dist2(a, b));

  /// Minimum distance from [point] to any segment in any of the rings.
  double _distToRings(Offset point, List<List<Offset>> rings) {
    double minD = double.infinity;
    for (final ring in rings) {
      for (var i = 0; i < ring.length - 1; i++) {
        final d = _distToSegment(point, ring[i], ring[i + 1]);
        if (d < minD) minD = d;
      }
    }
    return minD;
  }

  /// Perpendicular distance from [p] to segment [a]→[b], clamped to endpoints.
  double _distToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return _dist(p, a);
    final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
    final tc = t.clamp(0.0, 1.0);
    return _dist(p, Offset(a.dx + tc * dx, a.dy + tc * dy));
  }
}
