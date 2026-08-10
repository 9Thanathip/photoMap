import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'asset_thumbnail_provider.dart';
import 'progressive_image.dart';

/// photo_manager sizes thumbnails in **raw pixels**, so a size picked in
/// logical units (200 for a ~130pt grid tile) gets upscaled by the device
/// pixel ratio and renders soft — 2x–3x blur on a modern phone.
///
/// [assetThumbPx] converts a logical box into the pixel size actually needed.
/// Results are rounded up to [_step] so small layout differences don't spawn a
/// new decode + cache entry for every tile.
const int _step = 100;

/// Size of the cheap first pass every thumbnail shows while its real decode is
/// in flight.
///
/// Fixed on purpose: it is the same cache entry at every grid density and on
/// every screen, so after a photo has been seen once its preview is always
/// warm — and it is small enough (64 KB decoded) that thousands of them fit in
/// the image cache.
const int kThumbPreviewPixels = 128;

/// The shared cheap-preview provider for [asset].
///
/// `fast` is the whole point: it asks iOS for the rendition it already has
/// rather than rendering one, which is the difference between a preview that
/// beats the real tile and one that arrives alongside it.
AssetThumbnailProvider assetPreviewProvider(AssetEntity asset) =>
    AssetThumbnailProvider(
      asset,
      size: const ThumbnailSize.square(kThumbPreviewPixels),
      quality: 55,
      fast: true,
      // See AssetThumbnailProvider.format — PNG keeps ImageIO quiet at a size
      // where the extra bytes cost nothing.
      format: ThumbnailFormat.png,
    );

ThumbnailSize assetThumbPx(
  BuildContext context,
  Size logical, {
  int maxPixels = 1600,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  int px(double side) {
    final raw = side.isFinite && side > 0 ? side * dpr : maxPixels.toDouble();
    final stepped = (raw / _step).ceil() * _step;
    return stepped.clamp(_step, maxPixels);
  }

  return ThumbnailSize(px(logical.width), px(logical.height));
}

/// Device-asset thumbnail sized from the box it actually occupies.
///
/// Prefer this over a bare [AssetEntityImageProvider] with a hardcoded
/// [ThumbnailSize] — that is what makes thumbnails look blurry.
class AssetThumb extends StatelessWidget {
  const AssetThumb({
    super.key,
    required this.asset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.maxPixels = 1600,
    this.placeholder,
    this.colorFilter,
  });

  final AssetEntity asset;
  final BoxFit fit;
  final Alignment alignment;

  /// Logical size hint, used when the parent doesn't constrain that axis.
  final double? width;
  final double? height;

  /// Upper bound on the requested pixel size — raise it for full-screen
  /// surfaces, keep it low for dense grids.
  final int maxPixels;

  /// Shown until the cheap preview decode lands — after that the preview
  /// itself is the placeholder.
  final Widget? placeholder;

  /// Applied to the decoded image (film presets, previews).
  final ColorFilter? colorFilter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = Size(
          _resolve(constraints.maxWidth, width),
          _resolve(constraints.maxHeight, height),
        );
        // Square-ish request: asking for the longer side on both axes keeps
        // BoxFit.cover crops sharp regardless of the photo's orientation.
        final side = math.max(logical.width, logical.height);
        final size = assetThumbPx(
          context,
          Size(side, side),
          maxPixels: maxPixels,
        );

        final provider = AssetThumbnailProvider(asset, size: size);

        // Below roughly the preview's own resolution a second decode buys
        // nothing — the tile is already tiny.
        final worthPreviewing = size.width > kThumbPreviewPixels * 1.5;

        Widget image = worthPreviewing
            ? ProgressiveImage(
                preview: assetPreviewProvider(asset),
                image: provider,
                fit: fit,
                alignment: alignment,
                // Default (low) resamples poorly whenever the image isn't
                // drawn 1:1.
                filterQuality: FilterQuality.medium,
                placeholder: placeholder,
              )
            : Image(
                image: provider,
                fit: fit,
                alignment: alignment,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSync) =>
                    (wasSync || frame != null)
                        ? child
                        : (placeholder ?? const SizedBox.shrink()),
              );

        if (width != null || height != null) {
          image = SizedBox(width: width, height: height, child: image);
        }

        if (colorFilter != null) {
          image = ColorFiltered(colorFilter: colorFilter!, child: image);
        }
        return image;
      },
    );
  }

  static double _resolve(double constraint, double? hint) {
    if (constraint.isFinite && constraint > 0) return constraint;
    if (hint != null && hint > 0) return hint;
    return 0; // falls back to maxPixels in assetThumbPx
  }
}
