import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/gallery_notifier.dart';

class PhotoTile extends StatefulWidget {
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
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile> {
  bool _pressed = false;

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final asset = widget.photo.assetEntity;
    final isVideo = asset?.type == AssetType.video;

    Widget thumbnail = asset != null
        ? Image(
            image: AssetEntityImageProvider(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(200),
            ),
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              if (frame == null) {
                return const ShimmerThumbnail();
              }
              return child;
            },
          )
        : const ShimmerThumbnail();

    // Overlay play icon + duration for videos
    Widget image = isVideo
        ? Stack(
            fit: StackFit.expand,
            children: [
              thumbnail,
              const Align(
                alignment: Alignment.center,
                child: Icon(Icons.play_circle_filled_rounded,
                    color: Colors.white, size: 28),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Text(
                  _fmtDuration(asset!.videoDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
              ),
            ],
          )
        : thumbnail;

    Widget content = widget.isSelectMode
        ? Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (!widget.isSelected)
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
                    color: widget.isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: widget.isSelected
                          ? theme.colorScheme.primary
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: widget.isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ],
          )
        : image;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Hero(
          tag: widget.photo.path, // Using path as unique ID
          child: content,
        ),
      ),
    );
  }
}

class ShimmerThumbnail extends StatelessWidget {
  const ShimmerThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]!,
      highlightColor: isDark ? Colors.white.withAlpha(25) : Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }
}
