import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

class DistrictPhotosGrid extends StatelessWidget {
  const DistrictPhotosGrid({
    super.key,
    required this.photos,
    required this.districtName,
  });

  final List<PhotoItem> photos;
  final String districtName;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 80,
        8,
        8,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        if (photo.assetEntity == null) return const SizedBox();
        return AssetEntityImage(
          photo.assetEntity!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize(300, 300),
          fit: BoxFit.cover,
        );
      },
    );
  }
}
