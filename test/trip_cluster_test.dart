import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/trips/domain/trip.dart';

// Bangkok-ish home, Chiang Mai ~580km north, Phuket ~680km south.
const homeLat = 13.75, homeLng = 100.50;
const cmLat = 18.79, cmLng = 98.99;
const phuketLat = 7.88, phuketLng = 98.39;

PhotoItem p(
  String province,
  double lat,
  double lng,
  int y,
  int m,
  int d, [
  int hour = 12,
]) =>
    PhotoItem(
      path: '$province-$y$m$d-$hour-$lat',
      country: 'Thailand',
      province: province,
      timestamp: DateTime(y, m, d, hour),
      lat: lat,
      lng: lng,
    );

/// 30 days of home photos so home detection has something dominant to find.
List<PhotoItem> homeDays(int count, {int startDay = 1}) => [
      for (var i = 0; i < count; i++)
        p('Bangkok', homeLat, homeLng, 2025, 1, startDay + i),
    ];

void main() {
  test('home-only library yields no trips', () {
    expect(Trip.cluster(homeDays(20)), isEmpty);
  });

  test('one away run becomes one trip', () {
    final photos = [
      ...homeDays(20),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 10),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 11),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 12),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 13),
    ];
    final trips = Trip.cluster(photos);
    expect(trips.length, 1);
    expect(trips.first.days, 4);
    expect(trips.first.destination, 'Chiang Mai');
    expect(trips.first.photos.length, 4);
  });

  test('returning home splits two trips to the same place', () {
    final photos = [
      ...homeDays(20),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 10),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 11),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 12),
      p('Bangkok', homeLat, homeLng, 2025, 2, 13), // home again
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 14),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 15),
      p('Chiang Mai', cmLat, cmLng, 2025, 2, 16),
    ];
    expect(Trip.cluster(photos).length, 2);
  });

  test('far jump across a day boundary splits', () {
    final photos = [
      ...homeDays(20),
      p('Chiang Mai', cmLat, cmLng, 2025, 3, 1),
      p('Chiang Mai', cmLat, cmLng, 2025, 3, 2),
      p('Chiang Mai', cmLat, cmLng, 2025, 3, 3),
      p('Phuket', phuketLat, phuketLng, 2025, 3, 4),
      p('Phuket', phuketLat, phuketLng, 2025, 3, 5),
      p('Phuket', phuketLat, phuketLng, 2025, 3, 6),
    ];
    expect(Trip.cluster(photos).length, 2);
  });

  test('gap longer than maxGapDays splits', () {
    final photos = [
      ...homeDays(20),
      p('Chiang Mai', cmLat, cmLng, 2025, 4, 1),
      p('Chiang Mai', cmLat, cmLng, 2025, 4, 2),
      p('Chiang Mai', cmLat, cmLng, 2025, 4, 3),
      // 4-day pause, no home photo in between
      p('Chiang Mai', cmLat, cmLng, 2025, 4, 7),
      p('Chiang Mai', cmLat, cmLng, 2025, 4, 8),
      p('Chiang Mai', cmLat, cmLng, 2025, 4, 9),
    ];
    expect(Trip.cluster(photos).length, 2);
  });

  test('midnight-crossing photos are one day apart, not zero', () {
    expect(
      Trip.dayGap(DateTime(2025, 5, 1, 23, 50), DateTime(2025, 5, 2, 0, 10)),
      1,
    );
  });

  test('short runs are dropped as noise', () {
    final photos = [
      ...homeDays(20),
      p('Chiang Mai', cmLat, cmLng, 2025, 6, 1),
      p('Chiang Mai', cmLat, cmLng, 2025, 6, 2),
    ];
    expect(Trip.cluster(photos), isEmpty);
  });

  test('stops follow travel order and carry their own stay length', () {
    final photos = [
      ...homeDays(20),
      p('Lampang', 18.29, 99.49, 2025, 7, 1),
      p('Lampang', 18.29, 99.49, 2025, 7, 2),
      p('Chiang Mai', cmLat, cmLng, 2025, 7, 3),
      p('Chiang Mai', cmLat, cmLng, 2025, 7, 4),
      p('Chiang Mai', cmLat, cmLng, 2025, 7, 5),
    ];
    final trip = Trip.cluster(photos).single;
    expect(trip.stops.map((s) => s.province).toList(),
        ['Lampang', 'Chiang Mai']);
    expect(trip.stops[0].days, 2);
    expect(trip.stops[1].days, 3);
    expect(trip.destination, 'Chiang Mai');
  });

  test('a stray shot does not shatter a stay into extra stops', () {
    final photos = [
      ...homeDays(20),
      p('Chiang Mai', cmLat, cmLng, 2025, 8, 1),
      p('Chiang Mai', cmLat, cmLng, 2025, 8, 2, 9),
      // one border-adjacent shot mid-stay
      p('Lamphun', 18.57, 99.00, 2025, 8, 2, 13),
      p('Chiang Mai', cmLat, cmLng, 2025, 8, 2, 18),
      p('Chiang Mai', cmLat, cmLng, 2025, 8, 3),
    ];
    final trip = Trip.cluster(photos).single;
    expect(trip.stops.length, 1);
    expect(trip.stops.single.province, 'Chiang Mai');
  });

  test('home is found from repeat visits, not just day count', () {
    final photos = [
      // Six separate one-day visits home — few days, but you keep returning.
      for (var i = 0; i < 6; i++)
        p('Bangkok', homeLat, homeLng, 2025, 10, 1 + i * 4),
      p('Chiang Mai', cmLat, cmLng, 2025, 11, 1),
      p('Chiang Mai', cmLat, cmLng, 2025, 11, 2),
      p('Chiang Mai', cmLat, cmLng, 2025, 11, 3),
    ];
    final trips = Trip.cluster(photos);
    expect(trips.length, 1);
    expect(trips.single.destination, 'Chiang Mai');
  });

  test('no home detected still clusters by gap and distance', () {
    // Every photo somewhere different — no cell dominant enough to be home.
    final photos = [
      p('Chiang Mai', cmLat, cmLng, 2025, 9, 1),
      p('Chiang Mai', cmLat, cmLng, 2025, 9, 2),
      p('Chiang Mai', cmLat, cmLng, 2025, 9, 3),
      p('Phuket', phuketLat, phuketLng, 2025, 9, 20),
      p('Phuket', phuketLat, phuketLng, 2025, 9, 21),
      p('Phuket', phuketLat, phuketLng, 2025, 9, 22),
    ];
    final trips = Trip.cluster(photos);
    expect(trips.length, 2);
    // Newest first.
    expect(trips.first.destination, 'Phuket');
  });
}
