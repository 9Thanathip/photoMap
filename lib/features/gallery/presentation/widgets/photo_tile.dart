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
    this.isSelectMode = false,
    this.isSelected = false,
  });

  final PhotoItem photo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelectMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget image = photo.assetEntity != null
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
          );

    Widget content = isSelectMode
        ? Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (!isSelected)
                const ColoredBox(color: Color(0x33000000)),
              Positioned(
                top: 4,
                right: 4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ],
          )
        : image;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    );
  }
}
