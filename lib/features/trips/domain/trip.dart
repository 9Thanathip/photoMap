import 'dart:math' as math;

import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

/// One leg of a trip: the consecutive days spent in a single province.
///
/// Every calendar day of a trip belongs to exactly one stop — the province
/// that held most of that day's hours — so the stops' [days] add back up to
/// the trip's own length instead of drifting away from it.
class TripStop {
  const TripStop({
    required this.province,
    required this.country,
    required this.photos,
    required this.days,
    required this.nights,
    required this.presence,
  });

  final String province;
  final String country;

  /// Every photo taken while the trip was here, in order — including shots
  /// from a day trip out and back, so no photo drops out of the itinerary.
  final List<PhotoItem> photos;

  /// Calendar days this stop owns. Adds up with the other stops to `Trip.days`.
  final int days;

  /// Nights slept here. Adds up with the other stops to `Trip.days - 1`.
  final int nights;

  /// Time actually spent inside the province, from photo-to-photo attribution.
  final Duration presence;

  DateTime get start => photos.first.timestamp;
  DateTime get end => photos.last.timestamp;
  int get photoCount => photos.length;
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

  /// Hours in a province, with no night slept, below which the place was
  /// passed through rather than stayed in — a rest stop on the way north,
  /// not a destination. Those days fold into the stay around them.
  static const minStopHours = 4;

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

  int get nights => math.max(0, days - 1);

  /// Headline place — the stop the trip spent the longest in.
  String get destination {
    if (stops.isEmpty) return '';
    var best = stops.first;
    for (final s in stops) {
      final longer = s.presence > best.presence;
      final tied = s.presence == best.presence && s.photoCount > best.photoCount;
      if (longer || tied) best = s;
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

  /// Collapses a trip's photos into an ordered itinerary.
  ///
  /// Works off elapsed time rather than photo counts: the gap between two
  /// shots is time spent somewhere, so a single snap at a rest stop can't
  /// outvote a whole afternoon. Each calendar day goes to the province that
  /// held most of its hours, neighbouring days in the same province merge,
  /// and places only passed through fold into the stay around them.
  static List<TripStop> _stops(List<PhotoItem> bucket) {
    final origin = bucket.first.timestamp;
    final dayCount = dayGap(origin, bucket.last.timestamp) + 1;

    final byDay = List.generate(dayCount, (_) => <PhotoItem>[]);
    for (final p in bucket) {
      byDay[dayGap(origin, p.timestamp)].add(p);
    }

    final spans = _attribute(bucket);

    // ── Who owns each calendar day ──
    final seconds = List.generate(dayCount, (_) => <String, int>{});
    for (final span in spans) {
      var cursor = span.from;
      while (cursor.isBefore(span.to)) {
        final nextMidnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
        final sliceEnd = nextMidnight.isBefore(span.to) ? nextMidnight : span.to;
        final i = dayGap(origin, cursor);
        if (i < dayCount) {
          seconds[i][span.province] = (seconds[i][span.province] ?? 0) +
              sliceEnd.difference(cursor).inSeconds;
        }
        cursor = sliceEnd;
      }
    }

    // Photo-less days inherit the day before them, so the itinerary stays a
    // gapless partition of the trip even when the camera stayed in the bag.
    final owner = <String>[];
    var previous = bucket.first.province;
    for (var i = 0; i < dayCount; i++) {
      previous = _busiest(seconds[i]) ?? _majority(byDay[i]) ?? previous;
      owner.add(previous);
    }

    // ── Consecutive days in one province become one run ──
    final runs = <_Run>[];
    for (var i = 0; i < dayCount; i++) {
      if (runs.isNotEmpty && runs.last.province == owner[i]) {
        runs.last.lastDay = i;
      } else {
        runs.add(_Run(owner[i], i));
      }
    }
    for (final run in runs) {
      run.photoCount = _photosIn(byDay, run).length;
    }

    // ── Nights: whoever holds the stroke of midnight slept there ──
    for (var i = 1; i < dayCount; i++) {
      final midnight = DateTime(origin.year, origin.month, origin.day + i);
      final slept = _sleeperAt(spans, midnight);
      final evening = _runAt(runs, i - 1);
      final morning = _runAt(runs, i);
      final target = slept == morning.province && slept != evening.province
          ? morning
          : evening;
      target.nights++;
    }

    _measure(runs, spans, origin);
    _collapse(runs, spans, origin);

    return [
      for (final run in runs)
        if (_photosIn(byDay, run) case final photos when photos.isNotEmpty)
          TripStop(
            province: run.province,
            country: photos
                .firstWhere((p) => p.province == run.province,
                    orElse: () => photos.first)
                .country,
            photos: List.unmodifiable(photos),
            days: run.lastDay - run.firstDay + 1,
            nights: run.nights,
            presence: run.presence,
          ),
    ];
  }

  /// Splits the trip's whole timeline between provinces. Two shots in the
  /// same province mean the hours between them were spent there, night
  /// included. Two shots in different provinces mean travel, so that gap
  /// splits down the middle.
  static List<_Span> _attribute(List<PhotoItem> bucket) {
    final spans = <_Span>[];
    for (var i = 0; i + 1 < bucket.length; i++) {
      final a = bucket[i];
      final b = bucket[i + 1];
      if (!b.timestamp.isAfter(a.timestamp)) continue;
      if (a.province == b.province) {
        spans.add(_Span(a.province, a.timestamp, b.timestamp, a.province));
      } else {
        // Both halves of a move sleep at the destination: a midnight spent on
        // the road belongs to where you woke up, not to the province the car
        // happened to be in.
        final mid = a.timestamp.add(b.timestamp.difference(a.timestamp) ~/ 2);
        spans.add(_Span(a.province, a.timestamp, mid, b.province));
        spans.add(_Span(b.province, mid, b.timestamp, b.province));
      }
    }
    return spans;
  }

  /// Time spent in each run's own province while that run was current.
  static void _measure(List<_Run> runs, List<_Span> spans, DateTime origin) {
    for (final run in runs) {
      final from = DateTime(origin.year, origin.month, origin.day + run.firstDay);
      final to =
          DateTime(origin.year, origin.month, origin.day + run.lastDay + 1);
      var total = 0;
      for (final span in spans) {
        if (span.province != run.province) continue;
        final s = span.from.isAfter(from) ? span.from : from;
        final e = span.to.isBefore(to) ? span.to : to;
        if (e.isAfter(s)) total += e.difference(s).inSeconds;
      }
      run.presence = Duration(seconds: total);
    }
  }

  /// Folds pass-through provinces into the stay around them, then re-merges
  /// any stays left touching. Mutates [runs] in place; a stay that swallows
  /// a day is re-measured before it can be judged a pass-through itself.
  static void _collapse(List<_Run> runs, List<_Span> spans, DateTime origin) {
    while (runs.length > 1) {
      final i = runs.indexWhere((r) =>
          r.photoCount == 0 ||
          (r.nights == 0 && r.presence.inHours < minStopHours));
      if (i < 0) break;

      final run = runs[i];
      final into = runs[i > 0 ? i - 1 : i + 1];
      into.firstDay = math.min(into.firstDay, run.firstDay);
      into.lastDay = math.max(into.lastDay, run.lastDay);
      into.nights += run.nights;
      into.photoCount += run.photoCount;
      runs.removeAt(i);

      for (var j = runs.length - 1; j > 0; j--) {
        if (runs[j].province != runs[j - 1].province) continue;
        runs[j - 1].lastDay = runs[j].lastDay;
        runs[j - 1].nights += runs[j].nights;
        runs[j - 1].photoCount += runs[j].photoCount;
        runs.removeAt(j);
      }

      _measure(runs, spans, origin);
    }
  }

  static List<PhotoItem> _photosIn(List<List<PhotoItem>> byDay, _Run run) => [
        for (var i = run.firstDay; i <= run.lastDay; i++) ...byDay[i],
      ];

  static _Run _runAt(List<_Run> runs, int day) =>
      runs.firstWhere((r) => day >= r.firstDay && day <= r.lastDay);

  static String? _sleeperAt(List<_Span> spans, DateTime t) {
    for (final span in spans) {
      if (!span.from.isAfter(t) && span.to.isAfter(t)) return span.sleeper;
    }
    return null;
  }

  /// Key with the largest positive value, insertion order breaking ties.
  static String? _busiest(Map<String, int> weights) {
    String? best;
    var top = 0;
    weights.forEach((key, value) {
      if (value > top) {
        top = value;
        best = key;
      }
    });
    return best;
  }

  static String? _majority(List<PhotoItem> photos) {
    if (photos.isEmpty) return null;
    final counts = <String, int>{};
    for (final p in photos) {
      counts[p.province] = (counts[p.province] ?? 0) + 1;
    }
    return _busiest(counts) ?? photos.first.province;
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

/// A stretch of the trip's timeline attributed to one province.
class _Span {
  const _Span(this.province, this.from, this.to, this.sleeper);

  final String province;
  final DateTime from;
  final DateTime to;

  /// Where a midnight inside this stretch counts as a night slept.
  final String sleeper;
}

/// A stop while it's still being built — day bounds shift as pass-through
/// provinces fold in, so this stays mutable until the itinerary settles.
class _Run {
  _Run(this.province, int day)
      : firstDay = day,
        lastDay = day;

  final String province;
  int firstDay;
  int lastDay;
  int nights = 0;
  int photoCount = 0;
  Duration presence = Duration.zero;
}
