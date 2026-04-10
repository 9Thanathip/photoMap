import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../providers/gallery_notifier.dart';

class PhotoOptionsSheet extends StatelessWidget {
  const PhotoOptionsSheet({
    super.key,
    required this.photo,
    required this.onAddToAlbums,
    required this.onDelete,
  });

  final PhotoItem photo;
  final VoidCallback onAddToAlbums;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = photo.assetEntity;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Thumbnail preview
        if (asset != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image(
                  image: AssetEntityImageProvider(
                    asset,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize(600, 400),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

        // Menu items
        _OptionTile(
          icon: Icons.photo_album_outlined,
          label: 'Add to Albums',
          onTap: onAddToAlbums,
        ),
        Divider(
          height: 1,
          indent: 56,
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
        _OptionTile(
          icon: Icons.delete_outline_rounded,
          label: 'Remove',
          color: theme.colorScheme.error,
          onTap: onDelete,
        ),

        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
