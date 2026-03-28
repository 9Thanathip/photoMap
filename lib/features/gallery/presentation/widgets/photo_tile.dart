import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_notifier.dart';

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
    required this.onLongPress,
  });

  final PhotoItem photo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: photo.assetEntity != null
          ? Image(
              image: AssetEntityImageProvider(
                photo.assetEntity!,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(200),
              ),
              fit: BoxFit.cover,
            )
          : Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            ),
    );
  }
}
