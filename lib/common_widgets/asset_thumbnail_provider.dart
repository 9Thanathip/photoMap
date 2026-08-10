import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/core/services/thumb_cache.dart';

/// Device-asset thumbnails with control over how much the platform is asked to
/// work for them.
///
/// [AssetEntityImageProvider] always routes through
/// [AssetEntity.thumbnailDataWithSize], which hardcodes JPEG **quality 100**
/// and leaves iOS on `DeliveryMode.opportunistic`. That makes even a 128px
/// request cost a full-fidelity render, which is why a "cheap preview" drawn
/// with it never actually arrived any sooner than the real tile.
///
/// This provider goes to [AssetEntity.thumbnailDataWithOption] directly so a
/// preview can ask for `DeliveryMode.fastFormat` — the rendition iOS already
/// has on hand — at a quality nobody can tell apart once it is scaled up and
/// replaced a moment later.
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

  bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  ThumbnailOption get _option => _isApple
      ? ThumbnailOption.ios(
          size: size,
          format: format,
          quality: quality,
          deliveryMode:
              fast ? DeliveryMode.fastFormat : DeliveryMode.opportunistic,
          resizeMode: ResizeMode.fast,
          resizeContentMode: ResizeContentMode.fill,
        )
      : ThumbnailOption(size: size, format: format, quality: quality);

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

  /// Filename for this exact request. The modified date is in there so an
  /// edited photo doesn't keep serving its old thumbnail, and the asset id is
  /// base64url'd because iOS ids contain `/`.
  @visibleForTesting
  String get diskCacheKey {
    final id = base64Url.encode(utf8.encode(entity.id));
    final stamp = entity.modifiedDateSecond ?? 0;
    final ext = format == ThumbnailFormat.png ? 'png' : 'jpg';
    return '${id}_${size.width}x${size.height}_q$quality'
        '${fast ? '_f' : ''}_$stamp.$ext';
  }

  Future<ui.Codec> _load(
    AssetThumbnailProvider key,
    ImageDecoderCallback decode,
  ) async {
    final path = await ThumbCache.instance.pathFor(key.diskCacheKey);

    if (path != null && await File(path).exists()) {
      try {
        // Reads and decodes on a worker thread — no platform channel, and
        // nothing queued onto the iOS main thread.
        final buffer = await ui.ImmutableBuffer.fromFilePath(path);
        return decode(buffer);
      } catch (e) {
        // A truncated or corrupt entry shouldn't be fatal; drop it and refetch.
        debugPrint('AssetThumbnailProvider: bad cache entry, refetching: $e');
        unawaited(File(path).delete().catchError((_) => File(path)));
      }
    }

    final bytes = await key.entity.thumbnailDataWithOption(key._option);
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
