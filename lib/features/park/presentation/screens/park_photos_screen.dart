import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../gallery/presentation/providers/gallery_notifier.dart';
import '../../../gallery/presentation/widgets/main_gallery/photo_tile.dart';
import '../../../gallery/presentation/widgets/main_gallery/photos_tab.dart';
import '../../../gallery/presentation/widgets/viewer/photo_viewer_screen.dart';
import '../../data/national_parks.dart';

/// Shows the photos matched to a single national park in a grid; tapping a
/// tile opens the full-screen viewer (swipeable across the set).
class ParkPhotosScreen extends StatelessWidget {
  const ParkPhotosScreen({
    super.key,
    required this.park,
    required this.photos,
  });

  final NationalPark park;
  final List<PhotoItem> photos;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sorted = [...photos]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: t.surfaceBase,
      appBar: AppBar(
        backgroundColor: t.surfaceBase,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              park.nameEn,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            Text(
              '${sorted.length} photos',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          ],
        ),
      ),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(1.5, topPad > 0 ? 4 : 4, 1.5, 32),
        gridDelegate: photoGridDelegate,
        itemCount: sorted.length,
        itemBuilder: (_, i) => PhotoTile(
          photo: sorted[i],
          onTap: () => _openViewer(context, sorted, i),
          onLongPress: () {},
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, List<PhotoItem> list, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) => PhotoViewerScreen(
          photos: list,
          initialIndex: index,
          routeAnimation: animation,
        ),
      ),
    );
  }
}
