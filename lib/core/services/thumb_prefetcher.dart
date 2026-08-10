import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Asks the platform to get renditions ready for photos the grid is about to
/// reach.
///
/// On iOS this drives `PHCachingImageManager`, which prepares images on its own
/// queues. Without it every tile's first request waits for PhotoKit to produce
/// a rendition from scratch — the slow half of a cold scroll. It does not make
/// the request itself cheaper, only ready sooner, so it complements the
/// on-disk cache rather than replacing it.
class ThumbPrefetcher {
  ThumbPrefetcher._();

  static final ThumbPrefetcher instance = ThumbPrefetcher._();

  static const Duration _debounce = Duration(milliseconds: 120);

  Timer? _pending;
  String? _lastRange;
  bool _inFlight = false;

  /// Warms [assets] for a request of [size].
  ///
  /// Debounced, and skipped when the range hasn't moved: a fling emits a scroll
  /// notification per frame, and firing a platform call on each of them would
  /// cost more than it saves.
  void warm(List<AssetEntity> assets, ThumbnailSize size) {
    if (assets.isEmpty) return;
    final range = '${assets.first.id}:${assets.last.id}:${size.width}';
    if (range == _lastRange) return;
    _lastRange = range;

    _pending?.cancel();
    _pending = Timer(_debounce, () => unawaited(_run(assets, size)));
  }

  Future<void> _run(List<AssetEntity> assets, ThumbnailSize size) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      await PhotoCachingManager().requestCacheAssets(
        assets: assets,
        option: ThumbnailOption(size: size),
      );
    } catch (e) {
      debugPrint('ThumbPrefetcher: warm failed: $e');
    } finally {
      _inFlight = false;
    }
  }

  /// Drops outstanding work — leaving a grid, or tearing one down.
  void stop() {
    _pending?.cancel();
    _pending = null;
    _lastRange = null;
    unawaited(
      PhotoCachingManager().cancelCacheRequest().catchError((Object e) {
        debugPrint('ThumbPrefetcher: cancel failed: $e');
      }),
    );
  }
}
