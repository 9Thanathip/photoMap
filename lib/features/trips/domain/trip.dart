import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

/// A trip: a run of located photos with no gap longer than
/// [Trip.maxGapDays] between consecutive shots.
class Trip {
  const Trip({
    required this.start,
    required this.end,
    required this.photos,
    required this.provinces,
    required this.countries,
  });

  /// Consecutive photos further apart than this start a new trip.
  static const maxGapDays = 2;

  /// Trips with fewer photos than this are treated as noise.
  static const minPhotos = 2;

  final DateTime start;
  final DateTime end;
  final List<PhotoItem> photos;
  final Set<String> provinces;
  final Set<String> countries;

  int get days => end.difference(start).inDays + 1;

  /// Clusters located photos into trips, newest trip first.
  static List<Trip> cluster(List<PhotoItem> allPhotos) {
    final located = allPhotos
        .where((p) => p.hasLocation && p.province.isNotEmpty)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (located.isEmpty) return const [];

    final trips = <Trip>[];
    var bucket = <PhotoItem>[located.first];
    for (final p in located.skip(1)) {
      final gap = p.timestamp.difference(bucket.last.timestamp).inDays;
      if (gap > maxGapDays) {
        _emit(trips, bucket);
        bucket = [];
      }
      bucket.add(p);
    }
    _emit(trips, bucket);
    return trips.reversed.toList();
  }

  static void _emit(List<Trip> trips, List<PhotoItem> bucket) {
    if (bucket.length < minPhotos) return;
    trips.add(Trip(
      start: bucket.first.timestamp,
      end: bucket.last.timestamp,
      photos: List.unmodifiable(bucket),
      provinces: {for (final p in bucket) p.province},
      countries: {
        for (final p in bucket)
          if (p.country.isNotEmpty) p.country,
      },
    ));
  }
}
