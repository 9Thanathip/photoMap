import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Long edge, in pixels, an export should reach before it is worth keeping.
///
/// A map fills roughly a phone screen, so at the device's own ratio it comes
/// out around 1200px — fine on screen, soft the moment it is opened in Photos
/// and pinched into. This is about the size a phone camera writes.
const double kExportLongEdge = 2560;

/// Ceiling on the scale factor. A tablet-sized surface already exceeds
/// [kExportLongEdge] at its own ratio, and without a bound an unusual layout
/// could ask for a buffer measured in hundreds of megabytes.
const double kExportMaxScale = 5;

/// How much to oversample a surface [longestSide] logical units across.
///
/// Never below [devicePixelRatio]: rendering under it resamples the screen
/// down and the viewer scales it back up, which is exactly what made saved
/// maps look softer than the map on screen.
@visibleForTesting
double exportPixelRatio({
  required double devicePixelRatio,
  required double longestSide,
}) {
  if (longestSide <= 0 || !longestSide.isFinite) return devicePixelRatio;
  final wanted = math.max(devicePixelRatio, kExportLongEdge / longestSide);
  return math.min(wanted, kExportMaxScale);
}

/// Rasterises the [RepaintBoundary] behind [key] as PNG bytes.
///
/// Returns null when the boundary isn't in the tree — a screen that was
/// popped mid-export, mostly.
Future<Uint8List?> captureBoundaryPng(GlobalKey key) async {
  final context = key.currentContext;
  if (context == null) return null;
  final boundary = context.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;

  final image = await boundary.toImage(
    pixelRatio: exportPixelRatio(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      longestSide: boundary.size.longestSide,
    ),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    // A full-resolution export is tens of megabytes of texture; leaving it to
    // the finalizer is what turns two saves in a row into a memory warning.
    image.dispose();
  }
}
