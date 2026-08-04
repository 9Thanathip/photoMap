import 'package:flutter/material.dart';

import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../../gallery/presentation/widgets/main_gallery/photo_tile.dart';
import '../../../gallery/presentation/widgets/main_gallery/photos_tab.dart';
import '../../../gallery/presentation/widgets/viewer/photo_viewer_screen.dart';
import '../../domain/trip.dart';

/// One trip in full: every photo it holds, grouped under the stop it was
/// taken in. The viewer opens over the whole trip rather than the section,
/// so a swipe carries on into the next stop instead of dead-ending.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.trip});

  final Trip trip;

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

    // Stops are contiguous slices of trip.photos, so a running offset maps a
    // tile back to its index in the full trip.
    final sections = <Widget>[];
    var offset = 0;
    for (final stop in trip.stops) {
      final base = offset;
      offset += stop.photos.length;
      sections.add(
        SliverToBoxAdapter(child: _StopHeader(stop: stop)),
      );
      sections.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          sliver: SliverGrid(
            gridDelegate: photoGridDelegate,
            delegate: SliverChildBuilderDelegate(
              (_, i) => PhotoTile(
                photo: stop.photos[i],
                onTap: () => _openViewer(context, base + i),
                onLongPress: () {},
              ),
              childCount: stop.photos.length,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.surfaceBase,
      appBar: AppBar(
        backgroundColor: t.surfaceBase,
        title: Text(
          trip.destination,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Trip summary ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dateRange(trip.start, trip.end),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      l10n.tripStay(trip.days, trip.nights),
                      l10n.shareCardPhotos(trip.photos.length),
                      if (trip.stops.length > 1) l10n.tripStops(trip.stops.length),
                    ].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          ...sections,
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

/// Section title for one leg of the itinerary.
class _StopHeader extends StatelessWidget {
  const _StopHeader({required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accentGold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stop.province,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${l10n.tripStay(stop.days, stop.nights)} · '
            '${l10n.shareCardPhotos(stop.photoCount)}',
            style: TextStyle(fontSize: 12, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}
