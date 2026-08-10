import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// On-disk store of thumbnail bytes, keyed by exactly what was asked of the
/// platform.
///
/// Every miss is a platform round trip, and on iOS photo_manager services those
/// on the **main thread**: `PMManager.fetchThumb` dispatches the PHImageManager
/// request to the main queue and JPEG-encodes the result inside that callback.
/// A grid scrolling through a few hundred photos therefore hands the main
/// thread a few hundred encodes, which is what the stutter is made of — and it
/// happens again every time an entry falls out of the in-memory image cache.
///
/// Keeping the encoded bytes ourselves turns the second and every later request
/// into a file read on a worker thread, with the platform out of the picture.
class ThumbCache {
  ThumbCache._();

  static final ThumbCache instance = ThumbCache._();

  static const String _dirName = 'thumb_cache';

  /// Total size the cache is allowed to reach before the oldest entries go.
  /// Thumbnails are ~30 KB, so this is tens of thousands of them.
  static const int _maxBytes = 300 << 20;

  /// Swept back down to this much, so a sweep is rare rather than constant.
  static const int _targetBytes = 200 << 20;

  Future<Directory?>? _dir;
  bool _sweepScheduled = false;

  Future<Directory?> _directory() => _dir ??= _openDirectory();

  Future<Directory?> _openDirectory() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/$_dirName');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _scheduleSweep();
      return dir;
    } catch (e) {
      debugPrint('ThumbCache: cannot open cache dir: $e');
      return null;
    }
  }

  /// Absolute path an entry would live at, or null when there is no usable
  /// cache directory (in which case callers just go to the platform).
  Future<String?> pathFor(String key) async {
    final dir = await _directory();
    if (dir == null) return null;
    return '${dir.path}/$key';
  }

  Future<void> write(String path, Uint8List bytes) async {
    try {
      // Write beside the target and rename, so a kill mid-write can't leave a
      // truncated file that later decodes into a broken tile.
      final temp = File('$path.part');
      await temp.writeAsBytes(bytes, flush: false);
      await temp.rename(path);
    } catch (e) {
      debugPrint('ThumbCache: write failed: $e');
    }
  }

  /// Drops the oldest entries once, a few seconds after first use — never on
  /// the path that a tile is waiting on.
  void _scheduleSweep() {
    if (_sweepScheduled) return;
    _sweepScheduled = true;
    Timer(const Duration(seconds: 8), () => unawaited(sweep()));
  }

  Future<void> sweep() async {
    try {
      final dir = await _directory();
      if (dir == null) return;
      final entries = <_Entry>[];
      var total = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        total += stat.size;
        entries.add(_Entry(entity, stat.modified, stat.size));
      }
      if (total <= _maxBytes) return;

      entries.sort((a, b) => a.modified.compareTo(b.modified));
      for (final entry in entries) {
        if (total <= _targetBytes) break;
        try {
          await entry.file.delete();
          total -= entry.size;
        } catch (_) {
          // Another isolate may have taken it; the next sweep will catch up.
        }
      }
      debugPrint('ThumbCache: swept down to ${total >> 20} MB');
    } catch (e) {
      debugPrint('ThumbCache: sweep failed: $e');
    }
  }

  /// Wipes every entry. For a "clear cache" action, not for normal operation.
  Future<void> clear() async {
    try {
      final dir = await _directory();
      if (dir == null) return;
      await dir.delete(recursive: true);
      _dir = null;
    } catch (e) {
      debugPrint('ThumbCache: clear failed: $e');
    }
  }
}

class _Entry {
  const _Entry(this.file, this.modified, this.size);

  final File file;
  final DateTime modified;
  final int size;
}
