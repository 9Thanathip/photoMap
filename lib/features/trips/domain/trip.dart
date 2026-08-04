import 'dart:math' as math;

import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

/// One leg of a trip: the consecutive days spent in a single province.
///
/// Resolved per calendar day (the province holding that day's majority of
/// photos) so a border crossing or one stray shot doesn't shatter a stay
/// into a dozen stops.
class TripStop {
  const TripStop({
    required this.province,
    required this.country,
    required this.start,
    required this.end,
    required this.photoCount,
  });

  final String province;
  final String country;
  final DateTime start;
  final DateTime end;
  final int photoCount;

  int get days => Trip.dayGap(start, end) + 1;
}

/// A trip: a run of photos taken away from home, bounded by a long enough
/// pause, a return home, or a jump to a far enough destination.
class Trip {
  const Trip({
    required this.start,
    required this.end,
    required this.photos,
    required this.stops,
    required this.provinces,
    required this.countries,
  });

  // ── Clustering thresholds ──

  /// Calendar days between consecutive away shots that still count as the
  /// same trip. Measured on local dates, not elapsed hours — two photos
  /// either side of midnight are one day apart, not zero.
  static const maxGapDays = 2;

  /// A hop this far between consecutive away shots, across a day boundary,
  /// reads as a different destination rather than moving around within one.
  static const maxJumpKm = 350.0;

  /// Photos inside this radius of the detected home are not travel.
  static const homeRadiusKm = 30.0;

  /// Runs shorter than this are noise, not a trip.
  static const minPhotos = 3;

  /// Home has to account for at least this share of all photo-days before
  /// it's trusted — otherwise the busiest holiday spot would be "home".
  static const minHomeDayShare = 0.15;

  /// Separate visits (runs of days) that mark a place as somewhere you keep
  /// coming back to, rather than one long stay.
  static const minHomeVisits = 3;

  /// …or enough distinct days that a single unbroken run still reads as home
  /// (someone who shoots at home every day for weeks).
  static const minHomeDays = 12;

  /// Side of the grid cell home detection buckets photos into (degrees).
  static const _homeCellDeg = 0.25; // ≈ 28 km

  final DateTime start;
  final DateTime end;
  final List<PhotoItem> photos;

  /// The itinerary, in the order it was travelled.
  final List<TripStop> stops;

  final Set<String> provinces;
  final Set<String> countries;

  int get days => dayGap(start, end) + 1;

  /// Headline place — the stop the trip spent the most photos in.
  String get destination {
    if (stops.isEmpty) return '';
    var best = stops.first;
    for (final s in stops) {
      if (s.photoCount > best.photoCount) best = s;
    }
    return best.province;
  }

  /// Clusters located photos into trips, newest trip first.
  static List<Trip> cluster(List<PhotoItem> allPhotos) {
    final located =
        allPhotos.where((p) => p.hasLocation && p.province.isNotEmpty).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (located.isEmpty) return const [];

    final home = _detectHome(located);

    final trips = <Trip>[];
    var bucket = <PhotoItem>[];
    // Set when a home photo is seen; the next away photo on a later day
    // closes the trip — coming home is the clearest boundary there is.
    var wasHome = false;

    for (final p in located) {
      if (home != null && _km(p.lat, p.lng, home.$1, home.$2) <= homeRadiusKm) {
        wasHome = true;
        continue;
      }

      if (bucket.isNotEmpty) {
        final prev = bucket.last;
        final gap = dayGap(prev.timestamp, p.timestamp);
        final farJump = _km(prev.lat, prev.lng, p.lat, p.lng) > maxJumpKm;
        if (gap > maxGapDays || (gap >= 1 && (wasHome || farJump))) {
          _emit(trips, bucket);
          bucket = [];
        }
      }

      wasHome = false;
      bucket.add(p);
    }
    _emit(trips, bucket);

    return trips.reversed.toList();
  }

  /// Whole calendar days between two instants, ignoring time of day.
  static int dayGap(DateTime a, DateTime b) =>
      _midnight(b).difference(_midnight(a)).inDays.abs();

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);

  static int _dayNumber(DateTime t) =>
      _midnight(t).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  static void _emit(List<Trip> trips, List<PhotoItem> bucket) {
    if (bucket.length < minPhotos) return;
    final stops = _stops(bucket);
    if (stops.isEmpty) return;
    trips.add(Trip(
      start: bucket.first.timestamp,
      end: bucket.last.timestamp,
      photos: List.unmodifiable(bucket),
      stops: List.unmodifiable(stops),
      provinces: {for (final s in stops) s.province},
      countries: {
        for (final p in bucket)
          if (p.country.isNotEmpty) p.country,
      },
    ));
  }

  /// Collapses a trip's photos into an ordered itinerary. Each calendar day
  /// is assigned the province that holds most of that day's photos, then
  /// neighbouring days in the same province merge into one stop.
  static List<TripStop> _stops(List<PhotoItem> bucket) {
    // Day → photos, in travel order (bucket is already sorted).
    final dayOrder = <int>[];
    final byDay = <int, List<PhotoItem>>{};
    for (final p in bucket) {
      final d = _dayNumber(p.timestamp);
      final list = byDay.putIfAbsent(d, () {
        dayOrder.add(d);
        return [];
      });
      list.add(p);
    }

    final stops = <TripStop>[];
    String? runProvince;
    var runPhotos = <PhotoItem>[];

    void flush() {
      if (runProvince == null || runPhotos.isEmpty) return;
      stops.add(TripStop(
        province: runProvince,
        country: runPhotos.first.country,
        start: runPhotos.first.timestamp,
        end: runPhotos.last.timestamp,
        photoCount: runPhotos.length,
      ));
      runPhotos = [];
    }

    for (final d in dayOrder) {
      final dayPhotos = byDay[d]!;
      final counts = <String, int>{};
      for (final p in dayPhotos) {
        counts[p.province] = (counts[p.province] ?? 0) + 1;
      }
      var province = dayPhotos.first.province;
      var best = 0;
      counts.forEach((name, n) {
        if (n > best) {
          best = n;
          province = name;
        }
      });

      if (province != runProvince) {
        flush();
        runProvince = province;
      }
      runPhotos.addAll(dayPhotos);
    }
    flush();

    return stops;
  }

  /// Home is the grid cell you keep returning to — where life happens, not
  /// where the best photos were taken. A single long stay is a holiday, so a
  /// cell only qualifies on repeat visits, or on sheer number of days.
  /// Returns the centroid of the winning cell, or null when nothing
  /// qualifies (a library made only of trips has no home to subtract).
  static (double, double)? _detectHome(List<PhotoItem> located) {
    final days = <String, Set<int>>{};
    final sumLat = <String, double>{};
    final sumLng = <String, double>{};
    final counts = <String, int>{};
    final allDays = <int>{};

    for (final p in located) {
      final key = '${(p.lat / _homeCellDeg).floor()}:'
          '${(p.lng / _homeCellDeg).floor()}';
      final day = _dayNumber(p.timestamp);
      allDays.add(day);
      (days[key] ??= <int>{}).add(day);
      sumLat[key] = (sumLat[key] ?? 0) + p.lat;
      sumLng[key] = (sumLng[key] ?? 0) + p.lng;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    String? bestKey;
    var bestDays = 0;
    days.forEach((key, set) {
      if (set.length <= bestDays) return;
      if (set.length / allDays.length < minHomeDayShare) return;
      if (set.length < minHomeDays && _visits(set) < minHomeVisits) return;
      bestDays = set.length;
      bestKey = key;
    });

    final key = bestKey;
    if (key == null) return null;
    final n = counts[key]!;
    return (sumLat[key]! / n, sumLng[key]! / n);
  }

  /// Number of separate stays in a set of day numbers — a run of consecutive
  /// days counts once.
  static int _visits(Set<int> dayNumbers) {
    var visits = 0;
    for (final d in dayNumbers) {
      if (!dayNumbers.contains(d - 1)) visits++;
    }
    return visits;
  }

  /// Great-circle distance in kilometres.
  static double _km(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
