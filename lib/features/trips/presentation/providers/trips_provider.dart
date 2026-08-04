import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import '../../domain/trip.dart';

/// Trips derived from the gallery. Clustering walks every located photo and
/// runs home detection, so it's memoised here rather than recomputed inside
/// each screen's `build`.
final tripsProvider = Provider<List<Trip>>((ref) {
  final photos = ref.watch(galleryStateProvider.select((s) => s.allPhotos));
  return Trip.cluster(photos);
});
