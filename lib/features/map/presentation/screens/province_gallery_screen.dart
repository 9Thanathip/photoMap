import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_empty_state.dart';
import '../../../gallery/presentation/providers/gallery_notifier.dart';
import '../../../gallery/presentation/widgets/photo_tile.dart';
import '../../../gallery/presentation/widgets/photo_viewer_screen.dart';
import '../../../gallery/presentation/widgets/photos_tab.dart' show photoGridDelegate;

class ProvinceGalleryScreen extends ConsumerWidget {
  const ProvinceGalleryScreen({super.key, required this.provinceName});

  final String provinceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(galleryStateProvider);
    final photos = gallery.allPhotos
        .where((p) => p.province == provinceName)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: Text(provinceName),
        centerTitle: true,
      ),
      body: photos.isEmpty
          ? AppEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No photos in $provinceName',
              subtitle: 'Photos you take in this province will appear here.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(1.5),
              gridDelegate: photoGridDelegate,
              itemCount: photos.length,
              itemBuilder: (_, i) => PhotoTile(
                photo: photos[i],
                onTap: () => _openViewer(context, photos, i),
                onLongPress: () {},
              ),
            ),
    );
  }

  void _openViewer(
      BuildContext context, List<PhotoItem> photos, int index) {
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
