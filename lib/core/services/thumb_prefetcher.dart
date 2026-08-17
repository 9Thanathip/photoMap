import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class _Job {
  const _Job(this.assets, this.size, this.onReady);

  final List<AssetEntity> assets;
  final ThumbnailSize size;
  final void Function(List<AssetEntity> assets)? onReady;
}

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

  /// Shortest gap between two rounds of warming.
  static const Duration _interval = Duration(milliseconds: 120);

  Timer? _cooldown;
  _Job? _queued;
  String? _lastRange;
  bool _inFlight = false;

  /// Warms [assets] for a request of [size]. [onReady] runs on the same tick,
  /// for work that should follow the same rhythm — warming Flutter's own image
  /// cache, say.
  ///
  /// Rate-limited from the **leading** edge, which is the whole point. A fling
  /// emits a scroll notification every frame; under the trailing debounce this
  /// used to be, each of those cancelled the last one, so warming fired only
  /// once the list had already slowed down — precisely when it was no longer
  /// needed, and never during the fast scroll it exists for. Now the first
  /// notification fires immediately and the rest are capped to one round per
  /// [_interval], with the last one queued so the final position is never
  /// skipped.
  void warm(
    List<AssetEntity> assets,
    ThumbnailSize size, {
    void Function(List<AssetEntity> assets)? onReady,
  }) {
    if (assets.isEmpty) return;
    final range = '${assets.first.id}:${assets.last.id}:${size.width}';
    if (range == _lastRange) return;
    _lastRange = range;

    final job = _Job(assets, size, onReady);
    if (_cooldown != null) {
      _queued = job;
      return;
    }
    _fire(job);
  }

  void _fire(_Job job) {
    _queued = null;
    unawaited(_run(job.assets, job.size));
    job.onReady?.call(job.assets);
    _cooldown = Timer(_interval, () {
      _cooldown = null;
      final next = _queued;
      if (next != null) _fire(next);
    });
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
    _cooldown?.cancel();
    _cooldown = null;
    _queued = null;
    _lastRange = null;
    unawaited(
      PhotoCachingManager().cancelCacheRequest().catchError((Object e) {
        debugPrint('ThumbPrefetcher: cancel failed: $e');
      }),
    );
  }

  /// Clears the rate limiter between tests — it is a singleton, so state
  /// otherwise leaks from one test into the next.
  @visibleForTesting
  void resetForTest() {
    _cooldown?.cancel();
    _cooldown = null;
    _queued = null;
    _lastRange = null;
  }
}
