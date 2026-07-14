import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import '../../data/national_parks.dart';
import '../providers/national_parks_provider.dart';
import 'park_photos_screen.dart';

/// POC screen: scans located photos and shows which of Thailand's ~121 national
/// parks the user has visited (bounding-circle match on photo GPS), with a
/// per-park photo count. Parks are listed in full — visited first.
class NationalParksPocScreen extends ConsumerStatefulWidget {
  const NationalParksPocScreen({super.key});

  @override
  ConsumerState<NationalParksPocScreen> createState() =>
      _NationalParksPocScreenState();
}

class _NationalParksPocScreenState
    extends ConsumerState<NationalParksPocScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parksAsync = ref.watch(nationalParksProvider);
    final photos = ref.watch(galleryStateProvider).allPhotos;

    return Scaffold(
      backgroundColor: t.surfaceBase,
      appBar: AppBar(
        backgroundColor: t.surfaceBase,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'National Parks (POC)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
      ),
      body: parksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Load failed: $e',
              style: TextStyle(color: t.textSecondary)),
        ),
        data: (parks) => _buildList(context, t, parks, photos),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppTokens t,
    List<NationalPark> parks,
    List<PhotoItem> photos,
  ) {
    // Bucket photos per matched park.
    final byPark = <String, List<PhotoItem>>{};
    for (final p in photos) {
      if (!p.hasLocation) continue;
      final park = matchPark(parks, p.lat, p.lng);
      if (park != null) {
        byPark.putIfAbsent(park.id, () => []).add(p);
      }
    }
    int countOf(String id) => byPark[id]?.length ?? 0;

    final visitedCount = parks.where((p) => byPark.containsKey(p.id)).length;
    final located = photos.where((p) => p.hasLocation).length;

    final q = _query.trim().toLowerCase();
    bool matchQuery(NationalPark p) =>
        q.isEmpty ||
        p.nameEn.toLowerCase().contains(q) ||
        p.nameTh.contains(_query.trim());

    final visited = parks
        .where((p) => byPark.containsKey(p.id) && matchQuery(p))
        .toList()
      ..sort((a, b) => countOf(b.id).compareTo(countOf(a.id)));
    final notVisited = parks
        .where((p) => !byPark.containsKey(p.id) && matchQuery(p))
        .toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$located located photos · '
                '$visitedCount/${parks.length} parks visited',
                style: TextStyle(fontSize: 13, color: t.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14, color: t.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search park…',
                  hintStyle: TextStyle(color: t.textTertiary),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 20, color: t.textTertiary),
                  filled: true,
                  fillColor: t.surfaceMuted,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              if (visited.isNotEmpty) ...[
                _label('VISITED', t),
                const SizedBox(height: 10),
                for (final park in visited)
                  _ParkTile(
                    park: park,
                    count: countOf(park.id),
                    visited: true,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ParkPhotosScreen(
                          park: park,
                          photos: byPark[park.id]!,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              _label('NOT YET (${notVisited.length})', t),
              const SizedBox(height: 10),
              for (final park in notVisited)
                _ParkTile(park: park, count: 0, visited: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String s, AppTokens t) => Text(
        s,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: t.textSecondary,
        ),
      );
}

class _ParkTile extends StatelessWidget {
  const _ParkTile({
    required this.park,
    required this.count,
    required this.visited,
    this.onTap,
  });

  final NationalPark park;
  final int count;
  final bool visited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: visited ? t.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: visited ? Border.all(color: t.borderSubtle) : null,
        ),
        child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: visited ? t.accentGold : Colors.transparent,
              border: visited
                  ? null
                  : Border.all(color: t.textTertiary, width: 1.5),
            ),
            child: visited
                ? const Icon(Icons.forest_rounded, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  park.nameEn,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: visited ? FontWeight.w600 : FontWeight.w400,
                    color: visited ? t.textPrimary : t.textTertiary,
                  ),
                ),
                if (park.nameTh != park.nameEn)
                  Text(
                    park.nameTh,
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
              ],
            ),
          ),
          if (visited) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.textTertiary),
          ],
          ],
        ),
      ),
    );
  }
}
