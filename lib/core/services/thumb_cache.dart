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

  Directory? _ready;
  Future<void>? _opening;
  bool _sweepScheduled = false;

  /// Makes every temp file unique. See [write].
  int _seq = 0;

  Future<Directory?> _directory() async {
    if (_ready != null) return _ready;
    await (_opening ??= _openDirectory());
    return _ready;
  }

  Future<void> _openDirectory() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/$_dirName');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _ready = dir;
      _scheduleSweep();
    } catch (e) {
      debugPrint('ThumbCache: cannot open cache dir: $e');
    }
  }

  /// Absolute path an entry would live at, or null when the cache is not
  /// usable *right now*.
  ///
  /// Synchronous on purpose. Resolving the directory is a platform channel
  /// call, and awaiting it per tile put a channel round trip in front of every
  /// single thumbnail — one that, if it ever failed to answer, left every tile
  /// in the app waiting on it forever with nothing on screen. A caller that
  /// gets null just goes to the platform, which is what it does on a miss
  /// anyway; by the second frame the directory is ready.
  String? pathFor(String key) {
    final dir = _ready;
    if (dir == null) {
      unawaited(_directory());
      return null;
    }
    return '${dir.path}/$key';
  }

  /// Opens the cache directory ahead of first use, so no tile has to miss.
  Future<void> warmUp() => _directory().then((_) {});

  /// True when [path] holds an entry worth reading.
  ///
  /// A zero-length file is a write that never landed. It passes an `exists()`
  /// check and then fails to decode, which is how a broken entry used to turn
  /// into a platform round trip *plus* an exception on every single pass.
  Future<bool> isUsable(String path) async {
    try {
      final stat = await File(path).stat();
      return stat.type == FileSystemEntityType.file && stat.size > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> evict(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Already gone, which is the state we wanted.
    }
  }

  Future<void> write(String path, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    // Write beside the target and rename, so a kill mid-write can't leave a
    // truncated file that later decodes into a broken tile.
    //
    // The temp name has to be unique per write, not per entry: writeAsBytes
    // truncates, so two writers racing on one '$path.part' — the same photo
    // scrolled past twice, or a tile and the viewer's placeholder behind it —
    // interleave, and the rename then publishes the mixture as a finished
    // entry. That is exactly what the "bad cache entry" flood was made of.
    final temp = File('$path.${_seq++}.part');
    try {
      await temp.writeAsBytes(bytes, flush: false);
      await temp.rename(path);
    } catch (e) {
      debugPrint('ThumbCache: write failed: $e');
      unawaited(temp.delete().catchError((_) => temp));
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
        // A temp file belongs to a write that is still running.
        if (entity.path.endsWith('.part')) continue;
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
      _ready = null;
      _opening = null;
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
