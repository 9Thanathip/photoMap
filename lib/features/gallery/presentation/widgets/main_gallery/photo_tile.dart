import 'package:flutter/material.dart';
import 'package:photo_map/common_widgets/asset_thumb.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../providers/gallery_notifier.dart';
import 'package:photo_map/common_widgets/photo_grid.dart' show kPhotoTileMaxPixels;

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
        ? AssetThumb(
            asset: asset,
            maxPixels: kPhotoTileMaxPixels,
            // Only seen until the 128px preview lands, which is fast even on a
            // cold library — the tile's own decode takes far longer.
            placeholder: const ShimmerThumbnail(),
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
                child: Icon(AppIcons.play_circle_filled_rounded,
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
                      ? const Icon(AppIcons.check_rounded,
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

/// Flat fill shown under a tile that has nothing to draw yet.
///
/// Deliberately not a shimmer: `Shimmer.fromColors` is a [ShaderMask], and a
/// ShaderMask is a `saveLayer` — an offscreen render pass, per tile, on every
/// frame. Twenty tiles waiting on their first decode meant twenty extra passes
/// a frame on the raster thread, which cost far more than the decoding they
/// were there to apologise for.
class ShimmerThumbnail extends StatelessWidget {
  const ShimmerThumbnail({super.key});

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.tokens.shimmerBase);
}
