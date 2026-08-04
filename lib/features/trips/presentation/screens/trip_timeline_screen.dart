import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'package:photo_map/common_widgets/app_empty_state.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/features/gallery/presentation/widgets/viewer/photo_viewer_screen.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../domain/trip.dart';
import '../providers/trips_provider.dart';

/// Story-style timeline of auto-detected trips: date range, provinces,
/// and a thumbnail strip per trip. Tapping a thumbnail opens the shared
/// photo viewer scoped to that trip's photos.
class TripTimelineScreen extends ConsumerWidget {
  const TripTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    final trips = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: t.surfaceBase,
      appBar: AppBar(
        backgroundColor: t.surfaceBase,
        title: Text(
          l10n.tripsTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
          ),
        ),
      ),
      body: trips.isEmpty
          ? AppEmptyState(
              icon: AppIcons.explore_outlined,
              title: l10n.tripsEmptyTitle,
              subtitle: l10n.tripsEmptySubtitle,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: trips.length,
              itemBuilder: (context, i) => _TripCard(
                trip: trips[i],
                isFirst: i == 0,
                isLast: i == trips.length - 1,
              ),
            ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.isFirst,
    required this.isLast,
  });

  final Trip trip;
  final bool isFirst;
  final bool isLast;

  String _dateRange(AppLocalizations l10n) {
    final months = l10n.monthsShort;
    final s = trip.start;
    final e = trip.end;
    final sLabel = '${s.day} ${months[s.month - 1]}';
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return '$sLabel ${s.year}';
    }
    final eLabel = '${e.day} ${months[e.month - 1]}';
    return '$sLabel – $eLabel ${e.year}';
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) => PhotoViewerScreen(
          photos: trip.photos,
          initialIndex: index,
          routeAnimation: animation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline rail ──
          SizedBox(
            width: 24,
            child: Column(
              children: [
                SizedBox(
                  height: 6,
                  child: isFirst
                      ? null
                      : VerticalDivider(width: 2, color: t.borderSubtle),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.accentGold,
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : VerticalDivider(width: 2, color: t.borderSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── Card ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: t.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateRange(l10n),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      l10n.tripDays(trip.days),
                      l10n.shareCardPhotos(trip.photos.length),
                      if (trip.stops.length > 1) l10n.tripStops(trip.stops.length),
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  // Itinerary — stops in the order they were travelled, each
                  // carrying how long the trip stayed there.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in trip.stops)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.textPrimary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${s.province} · ${l10n.tripDaysShort(s.days)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Thumbnail strip
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: trip.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final asset = trip.photos[i].assetEntity;
                        if (asset == null) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () => _openViewer(context, i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(
                              image: AssetEntityImageProvider(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(160),
                              ),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
