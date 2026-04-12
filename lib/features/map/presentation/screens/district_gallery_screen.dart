import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photo_tile.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photo_viewer_screen.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photos_tab.dart' show photoGridDelegate;
import 'package:photo_map/features/map/presentation/widgets/province_district/province_header.dart';

class DistrictGalleryScreen extends ConsumerWidget {
  final String provinceName;
  final String districtName;
  final List<PhotoItem> photos;

  const DistrictGalleryScreen({
    super.key,
    required this.provinceName,
    required this.districtName,
    required this.photos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Photos Grid
          Positioned.fill(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                1.5,
                topPad + 80,
                1.5,
                16,
              ),
              gridDelegate: photoGridDelegate,
              itemCount: photos.length,
              itemBuilder: (_, i) => PhotoTile(
                photo: photos[i],
                onTap: () => _openViewer(context, photos, i),
                onLongPress: () {},
              ),
            ),
          ),

          // Header
          Positioned(
            top: topPad + 12,
            left: 20,
            right: 20,
            child: ProvinceHeader(
              title: '$districtName, $provinceName',
              viewMode: ProvinceViewMode.grid, // Doesn't matter here
              isSelectingDistrict: true, // Hides the toggle button
              onBack: () => Navigator.pop(context),
              onToggleMode: () {},
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<PhotoItem> photos, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: PhotoViewerScreen(photos: photos, initialIndex: index),
        ),
      ),
    );
  }
}
