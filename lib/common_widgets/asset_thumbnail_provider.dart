import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/core/services/thumb_cache.dart';

/// The thumbnail pipeline, in independently switchable pieces.
///
/// The switches are here because this area has twice shipped a build where the
/// grid rendered nothing at all and the logs said nothing about it. Turning a
/// piece off is how the next one gets diagnosed in one run instead of guessed
/// at over several — so each is described by what it buys, and none of them may
/// be folded together.
abstract final class ThumbPipeline {
  /// Keep encoded thumbnails on disk, keyed by exactly what was asked for.
  ///
  /// The big one. Without it every tile is a fresh PhotoKit request — on iOS
  /// those encode on the main thread — every time it scrolls back into view.
  static const bool diskCache = true;

  /// Paint a cheap 128px preview under each tile and cross-fade to the real
  /// one.
  ///
  /// Without it a tile has nothing to show until its full decode lands, and
  /// Flutter defers every load while a list is flinging — so a fast scroll is
  /// blank tiles followed by a burst of decodes when it stops. That burst is
  /// the stutter.
  static const bool progressive = true;

  /// Push those previews into Flutter's image cache ahead of the viewport.
  ///
  /// Only this can make a fling paint *during* the fling. [progressive] on its
  /// own still has to wait for the list to settle, because Flutter refuses to
  /// start any load while a list is moving fast unless the key is already
  /// cached; warming is what puts it there first.
  static const bool previewPrefetch = true;
}

/// Device-asset thumbnails, backed by an on-disk cache.
///
/// Two things photo_manager's own provider cannot do. It keeps nothing, so
/// every tile is a fresh platform request each time it scrolls back into view —
/// and on iOS each of those encodes a JPEG on the **main thread**. And it
/// always asks for a full-fidelity render, so a "cheap preview" drawn through
/// it never actually arrives any sooner than the real tile; going to
/// [AssetEntity.thumbnailDataWithOption] directly is what lets the preview ask
/// for `DeliveryMode.fastFormat`, the rendition iOS already has on hand.
@immutable
class AssetThumbnailProvider extends ImageProvider<AssetThumbnailProvider> {
  const AssetThumbnailProvider(
    this.entity, {
    required this.size,
    this.quality = 80,
    this.fast = false,
    this.format = ThumbnailFormat.jpeg,
  });

  final AssetEntity entity;
  final ThumbnailSize size;

  /// JPEG quality the platform encodes at, 1..100. The bytes are decoded and
  /// thrown away immediately, so anything near 100 is pure encode cost.
  /// Ignored for [ThumbnailFormat.png], which is lossless.
  final int quality;

  /// Take whatever the platform can produce quickest instead of waiting for a
  /// full-fidelity render. iOS only — elsewhere it just implies low quality.
  final bool fast;

  /// Wire format the platform encodes the thumbnail into before Flutter
  /// decodes it again.
  ///
  /// JPEG is right for anything tile-sized and up. PNG earns its keep only for
  /// the tiny preview: PhotoKit hands back an RGBA bitmap, and encoding that as
  /// JPEG makes ImageIO log `trying to save an opaque image with 'AlphaLast'`
  /// once per thumbnail — harmless, but hundreds of lines per fling is not
  /// free with a debugger attached. At 128px the size difference is noise.
  final ThumbnailFormat format;

  /// [DeliveryMode.opportunistic] is deliberate, and safe.
  ///
  /// It is the one mode PhotoKit answers twice — a degraded low-resolution pass
  /// first, then the real image — which looks like a trap. photo_manager drops
  /// the degraded pass rather than replying with it: `PMManager.fetchThumb`
  /// gates its reply on `isDownloadFinish`, which is
  /// `![info[PHImageResultIsDegradedKey] boolValue]`. So the caller only ever
  /// sees the final image, and gets it as soon as PhotoKit has one.
  ///
  /// [DeliveryMode.highQualityFormat] would be the paranoid choice and is much
  /// worse: it forces a full-fidelity decode of the original for every tile,
  /// all of it on the iOS main queue (see the `dispatch_async` in
  /// `fetchThumb`), which saturates that queue and stops *everything* — the
  /// cheap previews queued behind it included — from arriving at all.
  ThumbnailOption get _option =>
      buildOption(size, format: format, quality: quality, fast: fast);

  /// See [_option] for why the delivery mode is what it is.
  static ThumbnailOption buildOption(
    ThumbnailSize size, {
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    int quality = 80,
    bool fast = false,
  }) {
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!isApple) {
      return ThumbnailOption(size: size, format: format, quality: quality);
    }
    if (!fast) {
      // Byte-for-byte the request AssetEntityImageProvider makes, because that
      // one demonstrably puts photos on screen on this device and this one did
      // not. Quality 100 and aspect-fit are more work than a grid tile needs —
      // that tuning comes back once the pipeline in front of it is trusted, not
      // before, or the next result is unreadable again.
      return ThumbnailOption.ios(size: size, format: format);
    }
    return ThumbnailOption.ios(
      size: size,
      format: format,
      quality: quality,
      deliveryMode: DeliveryMode.fastFormat,
      resizeMode: ResizeMode.fast,
      resizeContentMode: ResizeContentMode.fill,
    );
  }

  @override
  Future<AssetThumbnailProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<AssetThumbnailProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    AssetThumbnailProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1.0,
      debugLabel: 'AssetThumbnail(${key.entity.id}, '
          '${key.size.width}x${key.size.height}, ${key.format.name}, '
          'q${key.quality}${key.fast ? ', fast' : ''})',
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<AssetEntity>('entity', key.entity),
        DiagnosticsProperty<ThumbnailSize>('size', key.size),
      ],
    );
  }

  /// Bumped whenever the request changes shape enough that entries written by
  /// an older build are wrong rather than merely stale.
  ///
  /// v3: the sharp request went back to photo_manager's own options after a
  /// build that rendered nothing at all. Anything that build managed to write
  /// is not worth trusting, and the key never described how the bytes were
  /// asked for, so only a version can retire them.
  static const int _cacheVersion = 3;

  /// Filename for this exact request. The modified date is in there so an
  /// edited photo doesn't keep serving its old thumbnail, and the asset id is
  /// base64url'd because iOS ids contain `/`.
  @visibleForTesting
  String get diskCacheKey {
    final id = base64Url.encode(utf8.encode(entity.id));
    final stamp = entity.modifiedDateSecond ?? 0;
    final ext = format == ThumbnailFormat.png ? 'png' : 'jpg';
    return '${id}_v${_cacheVersion}_${size.width}x${size.height}_q$quality'
        '${fast ? '_f' : ''}_$stamp.$ext';
  }

  /// The option a one-off request should use for an image that will be
  /// rendered into something the user keeps.
  ///
  /// Exposed because several places go to [AssetEntity.thumbnailDataWithSize]
  /// directly — the collage, the editor's source, the map covers — and that
  /// convenience method encodes at JPEG quality 100, which is pure encode cost
  /// for bytes that get decoded and thrown away. Same delivery, less work.
  static ThumbnailOption sharpOption(ThumbnailSize size, {int quality = 92}) =>
      buildOption(size, quality: quality);

  /// Bytes for a one-off request. See [sharpOption].
  static Future<Uint8List?> sharpBytes(
    AssetEntity entity,
    ThumbnailSize size, {
    int quality = 92,
  }) =>
      entity.thumbnailDataWithOption(sharpOption(size, quality: quality));

  /// How long one platform request is worth waiting on.
  ///
  /// A photo that lives in iCloud and isn't downloaded does not fail — PhotoKit
  /// waits for the download and photo_manager only replies once it finishes.
  /// Without a bound the tile just stays empty forever.
  static const Duration _fetchTimeout = Duration(seconds: 10);

  static Future<Uint8List?> _fetch(AssetThumbnailProvider key) =>
      key.entity.thumbnailDataWithOption(key._option).timeout(
        _fetchTimeout,
        onTimeout: () {
          debugPrint(
            'AssetThumbnailProvider: gave up on ${key.entity.id} '
            '(${key.size.width}px) after $_fetchTimeout',
          );
          return null;
        },
      );

  Future<ui.Codec> _load(
    AssetThumbnailProvider key,
    ImageDecoderCallback decode,
  ) async {
    final cacheKey = key.diskCacheKey;
    final path =
        ThumbPipeline.diskCache ? ThumbCache.instance.pathFor(cacheKey) : null;

    if (path != null && await ThumbCache.instance.isUsable(path)) {
      try {
        // Reads and decodes on a worker thread — no platform channel, and
        // nothing queued onto the iOS main thread.
        final buffer = await ui.ImmutableBuffer.fromFilePath(path);
        return decode(buffer);
      } catch (e) {
        // A corrupt entry shouldn't be fatal; drop it and refetch.
        debugPrint('AssetThumbnailProvider: bad cache entry, refetching: $e');
        unawaited(ThumbCache.instance.evict(path));
      }
    }

    final bytes = await _fetch(key);
    if (bytes == null || bytes.isEmpty) {
      // Let the caller's errorBuilder decide — for a preview that means
      // keeping the placeholder rather than painting a broken box.
      throw StateError('No thumbnail data for asset ${key.entity.id}');
    }
    if (path != null) {
      // Off the critical path: the tile paints from the bytes we already have.
      unawaited(ThumbCache.instance.write(path, bytes));
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is AssetThumbnailProvider &&
      other.entity == entity &&
      other.size == size &&
      other.quality == quality &&
      other.fast == fast &&
      other.format == format;

  @override
  int get hashCode => Object.hash(entity, size, quality, fast, format);
}
