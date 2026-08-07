import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// photo_manager sizes thumbnails in **raw pixels**, so a size picked in
/// logical units (200 for a ~130pt grid tile) gets upscaled by the device
/// pixel ratio and renders soft — 2x–3x blur on a modern phone.
///
/// [assetThumbPx] converts a logical box into the pixel size actually needed.
/// Results are rounded up to [_step] so small layout differences don't spawn a
/// new decode + cache entry for every tile.
const int _step = 100;

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
    this.frameBuilder,
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

  final ImageFrameBuilder? frameBuilder;

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

        Widget image = Image(
          image: AssetEntityImageProvider(
            asset,
            isOriginal: false,
            thumbnailSize: size,
          ),
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          // Default (low) resamples poorly whenever the image isn't drawn 1:1.
          filterQuality: FilterQuality.medium,
          frameBuilder: frameBuilder,
        );

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
