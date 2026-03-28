import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_notifier.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.coverPhoto,
    required this.onTap,
    this.leading,
  });

  final String title;
  final String subtitle;
  final String? leading;
  final PhotoItem coverPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: coverPhoto.assetEntity != null
                  ? Image(
                      image: AssetEntityImageProvider(
                        coverPhoto.assetEntity!,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize.square(300),
                      ),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.photo_library_outlined,
                          color: theme.colorScheme.onSurfaceVariant, size: 40),
                    ),
            ),
          ),
          const Gap(4),
          Row(
            children: [
              if (leading != null) ...[
                Text(leading!, style: const TextStyle(fontSize: 13)),
                const Gap(3),
              ],
              Expanded(
                child: Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(subtitle,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
