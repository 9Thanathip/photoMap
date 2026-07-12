import 'package:flutter/foundation.dart';

import '../../../utils/exif_reader.dart';

/// The available EXIF frame layouts. Each renders the same [FrameData] but
/// arranges the photo, borders and metadata differently.
enum FrameStyle {
  /// White strip below the photo: shooting settings on the left, camera
  /// brand + body on the right (the classic "Sony" look).
  bottomBar,

  /// Even white border on all sides (polaroid) with the metadata centred
  /// in the wider bottom margin.
  fullBorder,

  /// No border — metadata drawn directly over the bottom of the photo with a
  /// soft scrim for legibility.
  minimal,
}

extension FrameStyleX on FrameStyle {
  /// Stable id used for persistence / analytics.
  String get id => switch (this) {
        FrameStyle.bottomBar => 'bottom_bar',
        FrameStyle.fullBorder => 'full_border',
        FrameStyle.minimal => 'minimal',
      };
}

/// Immutable metadata a frame renders. Built from [PhotoExif] plus the photo's
/// capture time (taken from the gallery item, which is more reliable than the
/// EXIF DateTimeOriginal on many devices).
@immutable
class FrameData {
  const FrameData({
    required this.exif,
    required this.dateTime,
  });

  final PhotoExif exif;
  final DateTime dateTime;

  /// Left-hand settings line, e.g. `ISO100 50mm F2.8 1/1600s`. Omits any part
  /// that's unknown so we never print `ISO mm F`.
  String get settingsLine {
    final parts = <String>[
      if (exif.iso.isNotEmpty) 'ISO${exif.iso}',
      if (exif.focalMm.isNotEmpty) '${exif.focalMm}mm',
      if (exif.fNumber.isNotEmpty) 'F${exif.fNumber}',
      if (exif.exposure.isNotEmpty) exif.exposure,
    ];
    return parts.join('  ');
  }

  /// `2024/07/28 09:03:03` — matches the in-camera timestamp style.
  String get timestampLine {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = dateTime;
    return '${d.year}/${two(d.month)}/${two(d.day)}  '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  /// Camera line for the right side, e.g. `SONY ILCE-7C`.
  String get cameraLine => exif.camera;

  /// Lens line, e.g. `E 50mm F1.4` (falls back to the derived summary).
  String get lensLine => exif.lensModel.isNotEmpty ? exif.lensModel : exif.lens;

  bool get hasAnyMetadata => !exif.isEmpty;
}
