import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../presentation/providers/gallery_notifier.dart';

/// Sorts photos into a smooth colour gradient by dominant hue (the same look
/// as the collage builder's colour sort, applied to the whole library).
///
/// Tones are averaged from tiny 32x32 thumbnails, memoized in memory and
/// persisted to disk, so only newly-seen photos cost a decode. All I/O
/// failures degrade to "no tone" (photo sorts to the end) rather than throw.
class HueSortCache {
  HueSortCache._();

  static const _cacheFile = 'hue_tone_cache.json';
  static final Map<String, (double, double)> _tones = {};
  static bool _loaded = false;
  static bool _dirty = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFile');
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, dynamic>) {
          raw.forEach((k, v) {
            if (v is List && v.length == 2) {
              _tones[k] = ((v[0] as num).toDouble(), (v[1] as num).toDouble());
            }
          });
        }
      }
    } catch (e) {
      debugPrint('HueSortCache: load failed: $e');
    }
  }

  static Future<void> _persist() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFile');
      await file.writeAsString(jsonEncode(
        _tones.map((k, v) => MapEntry(k, [v.$1, v.$2])),
      ));
    } catch (e) {
      debugPrint('HueSortCache: save failed: $e');
    }
  }

  /// Returns [photos] reordered hue-first (secondary: brightness, so
  /// near-grey shots don't scatter). Photos whose tone can't be computed go
  /// to the end in their original order.
  static Future<List<PhotoItem>> sortByHue(
    List<PhotoItem> photos, {
    ValueChanged<double>? onProgress,
  }) async {
    await _ensureLoaded();

    final missing =
        photos.where((p) => !_tones.containsKey(p.path)).toList(growable: false);
    var done = 0;
    // Small batches keep memory flat and the UI responsive.
    const batch = 8;
    for (var i = 0; i < missing.length; i += batch) {
      final slice = missing.skip(i).take(batch);
      await Future.wait(slice.map((p) async {
        final tone = await _computeTone(p.assetEntity);
        if (tone != null) {
          _tones[p.path] = tone;
          _dirty = true;
        }
      }));
      done += batch;
      onProgress?.call((done / missing.length).clamp(0.0, 1.0));
    }
    await _persist();

    final toned = <PhotoItem>[];
    final unknown = <PhotoItem>[];
    for (final p in photos) {
      (_tones.containsKey(p.path) ? toned : unknown).add(p);
    }
    toned.sort((a, b) {
      final ta = _tones[a.path]!;
      final tb = _tones[b.path]!;
      final h = ta.$1.compareTo(tb.$1);
      return h != 0 ? h : ta.$2.compareTo(tb.$2);
    });
    return [...toned, ...unknown];
  }

  /// Average colour of the asset's 32x32 thumbnail as (hue 0..360, value
  /// 0..1), or null when unavailable.
  static Future<(double, double)?> _computeTone(AssetEntity? asset) async {
    if (asset == null) return null;
    try {
      final data =
          await asset.thumbnailDataWithSize(const ThumbnailSize(32, 32));
      if (data == null) return null;
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (bytes == null) return null;
      final b = bytes.buffer.asUint8List();
      var r = 0.0, g = 0.0, bl = 0.0;
      final n = b.length ~/ 4;
      for (var i = 0; i < b.length; i += 4) {
        r += b[i];
        g += b[i + 1];
        bl += b[i + 2];
      }
      final color = ui.Color.fromARGB(
          255, (r / n).round(), (g / n).round(), (bl / n).round());
      final hsv = HSVColor.fromColor(color);
      return (hsv.hue, hsv.value);
    } catch (e) {
      debugPrint('HueSortCache: tone failed: $e');
      return null;
    }
  }
}
