import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// Resolves a camera [make] to a bundled brand logo.
///
/// Logos live in `assets/camera_logos/<brand>.png` (white, transparent
/// background — drawn on the frame's light strip is fine because the painter
/// tints them). When no asset ships for a brand, [loadCameraLogo] returns null
/// and the painter falls back to a plain text wordmark, so the feature works
/// with zero logo assets and improves as real PNGs are dropped in.
class CameraLogo {
  const CameraLogo._();

  /// Maps common EXIF `Make` values to a canonical asset key.
  static String? assetKey(String make) {
    final m = make.toLowerCase().trim();
    if (m.isEmpty) return null;
    const table = <String, String>{
      'sony': 'sony',
      'canon': 'canon',
      'nikon': 'nikon',
      'nikon corporation': 'nikon',
      'fujifilm': 'fujifilm',
      'panasonic': 'panasonic',
      'leica': 'leica',
      'leica camera ag': 'leica',
      'olympus': 'olympus',
      'om digital solutions': 'olympus',
      'ricoh': 'ricoh',
      'pentax': 'pentax',
      'hasselblad': 'hasselblad',
      'gopro': 'gopro',
      'dji': 'dji',
      'apple': 'apple',
      'samsung': 'samsung',
      'google': 'google',
      'xiaomi': 'xiaomi',
      'huawei': 'huawei',
      'oneplus': 'oneplus',
      'oppo': 'oppo',
      'vivo': 'vivo',
    };
    // Direct hit, else first token (e.g. "NIKON D850" -> "nikon").
    return table[m] ?? table[m.split(RegExp(r'\s+')).first];
  }

  /// Loads the decoded logo image for [make], or null when no asset is bundled
  /// for that brand. Never throws.
  static Future<ui.Image?> load(String make) async {
    final key = assetKey(make);
    if (key == null) return null;
    try {
      final data = await rootBundle.load('assets/camera_logos/$key.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      // No asset shipped for this brand — caller uses the text fallback.
      return null;
    }
  }

  /// Text wordmark used when no logo asset exists, e.g. `SONY`.
  static String wordmark(String make) => make.toUpperCase();
}

/// Convenience for widgets that want to preload without importing dart:ui.
Future<ui.Image?> loadCameraLogo(String make) => CameraLogo.load(make);
