import 'package:flutter/material.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photo_tile.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photo_viewer_screen.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photos_tab.dart'
    show photoGridDelegate;

class DistrictPhotosGrid extends StatelessWidget {
  const DistrictPhotosGrid({
    super.key,
    required this.photos,
    required this.districtName,
  });

  final List<PhotoItem> photos;
  final String districtName;

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, animation, _) => FadeTransition(
          opacity: animation,
          child: PhotoViewerScreen(photos: photos, initialIndex: index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        1.5,
        MediaQuery.paddingOf(context).top + 80,
        1.5,
        8,
      ),
      gridDelegate: photoGridDelegate,
      itemCount: photos.length,
      itemBuilder: (context, index) => PhotoTile(
        photo: photos[index],
        onTap: () => _openViewer(context, index),
        onLongPress: () {},
      ),
    );
  }
}
