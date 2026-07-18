import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/province/presentation/widgets/achievements_stats.dart';

PhotoItem _photo({
  required String province,
  String country = 'Thailand',
  String path = 'p',
}) {
  return PhotoItem(
    path: path,
    country: country,
    province: province,
    timestamp: DateTime(2024, 1, 1),
    lat: 13.7,
    lng: 100.5,
  );
}

void main() {
  group('AchievementsStats.from', () {
    test('empty input yields empty stats', () {
      final s = AchievementsStats.from([]);
      expect(s.visitedProvinces, isEmpty);
      expect(s.photosByProvince, isEmpty);
      expect(s.countriesVisited, isEmpty);
    });

    test('skips photos with an empty province', () {
      final s = AchievementsStats.from([
        _photo(province: ''),
        _photo(province: 'Bangkok'),
      ]);
      expect(s.visitedProvinces, {'Bangkok'});
    });

    test('groups photos by province and counts them', () {
      final s = AchievementsStats.from([
        _photo(province: 'Bangkok', path: 'a'),
        _photo(province: 'Bangkok', path: 'b'),
        _photo(province: 'Phuket', path: 'c'),
      ]);
      expect(s.visitedProvinces, {'Bangkok', 'Phuket'});
      expect(s.photosByProvince['Bangkok']!.length, 2);
      expect(s.photosByProvince['Phuket']!.length, 1);
    });

    test('maps each country to its set of provinces', () {
      final s = AchievementsStats.from([
        _photo(country: 'Thailand', province: 'Bangkok'),
        _photo(country: 'Thailand', province: 'Phuket'),
        _photo(country: 'Japan', province: 'Tokyo'),
      ]);
      expect(s.countriesVisited['Thailand'], {'Bangkok', 'Phuket'});
      expect(s.countriesVisited['Japan'], {'Tokyo'});
    });

    test('photo with empty country is still counted in provinces', () {
      final s = AchievementsStats.from([
        _photo(country: '', province: 'Bangkok'),
      ]);
      expect(s.visitedProvinces, {'Bangkok'});
      expect(s.countriesVisited, isEmpty);
    });
  });
}
