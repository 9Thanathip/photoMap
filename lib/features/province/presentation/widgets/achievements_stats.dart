import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

class AchievementsStats {
  const AchievementsStats(
    this.visitedProvinces,
    this.photosByProvince,
    this.countriesVisited,
  );

  final Set<String> visitedProvinces;
  final Map<String, List<PhotoItem>> photosByProvince;
  final Map<String, Set<String>> countriesVisited;

  factory AchievementsStats.from(List<PhotoItem> photos) {
    final provinces = <String>{};
    final byProvince = <String, List<PhotoItem>>{};
    final countries = <String, Set<String>>{};
    for (final p in photos) {
      if (p.province.isEmpty) continue;
      provinces.add(p.province);
      byProvince.putIfAbsent(p.province, () => []).add(p);
      if (p.country.isNotEmpty) {
        countries.putIfAbsent(p.country, () => {}).add(p.province);
      }
    }
    return AchievementsStats(provinces, byProvince, countries);
  }
}
