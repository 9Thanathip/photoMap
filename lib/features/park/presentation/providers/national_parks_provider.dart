import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/national_parks.dart';

/// Loads the bundled national-park dataset once and caches it.
final nationalParksProvider = FutureProvider<List<NationalPark>>((ref) {
  return loadNationalParks();
});
