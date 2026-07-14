import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// A national park POC record: a name plus a bounding circle (centre + radius).
///
/// POC approximation — parks are matched by distance to their centre, not by
/// true polygon boundaries. Centre + radius are derived from each park's
/// OpenStreetMap bounding box (`assets/data/national_parks.json`). Swap for
/// GeoJSON polygon point-in-polygon later (same approach as [GeoService]).
class NationalPark {
  const NationalPark({
    required this.id,
    required this.nameEn,
    required this.nameTh,
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });

  factory NationalPark.fromJson(Map<String, dynamic> j) => NationalPark(
        id: j['id'] as String,
        nameEn: j['en'] as String,
        nameTh: (j['th'] ?? j['en']) as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        radiusKm: (j['r'] as num).toDouble(),
      );

  final String id;
  final String nameEn;
  final String nameTh;
  final double lat;
  final double lng;

  /// Approximate radius of the park's footprint, in km.
  final double radiusKm;
}

/// Loads the full Thai national-park dataset from the bundled asset.
/// ~121 parks sourced from OpenStreetMap.
Future<List<NationalPark>> loadNationalParks() async {
  final raw = await rootBundle.loadString('assets/data/national_parks.json');
  final list = json.decode(raw) as List<dynamic>;
  return [
    for (final e in list) NationalPark.fromJson(e as Map<String, dynamic>),
  ];
}

/// Earth radius in km.
const double _kEarthRadiusKm = 6371;

/// Great-circle distance between two lat/lng points, in km (haversine).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return _kEarthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180;

/// Returns the nearest park (from [parks]) whose bounding circle contains
/// [lat]/[lng], or null if the point is outside every park.
NationalPark? matchPark(List<NationalPark> parks, double lat, double lng) {
  NationalPark? best;
  double bestDist = double.infinity;
  for (final park in parks) {
    final d = haversineKm(lat, lng, park.lat, park.lng);
    if (d <= park.radiusKm && d < bestDist) {
      bestDist = d;
      best = park;
    }
  }
  return best;
}
