import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/core/services/thumb_cache.dart';

/// Big enough that a write takes long enough for a second writer to land in
/// the middle of it.
const int _size = 512 * 1024;

Uint8List _payload(int fill) => Uint8List(_size)..fillRange(0, _size, fill);

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('thumb_cache_test');
    path = '${dir.path}/entry.jpg';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  final cache = ThumbCache.instance;

  test('a written entry reads back whole', () async {
    await cache.write(path, _payload(0xAA));
    expect(await cache.isUsable(path), isTrue);
    expect(File(path).readAsBytesSync(), _payload(0xAA));
  });

  test('a racing writer never publishes an empty entry', () async {
    // The same rendition is written twice all the time: a photo scrolled past,
    // evicted, scrolled back to. A reader must never catch the entry
    // mid-publish — a zero-length file is what `ImmutableBuffer.fromFilePath`
    // reports as "Could not load file at ...", and each of those costs another
    // PhotoKit round trip on the iOS main thread.
    var sawEmpty = false;
    var writing = true;

    final watcher = () async {
      final file = File(path);
      while (writing) {
        try {
          if (file.existsSync() && file.lengthSync() == 0) sawEmpty = true;
        } catch (_) {
          // Renamed out from under the check; that is not the failure.
        }
        await Future<void>.delayed(Duration.zero);
      }
    }();

    await Future.wait([
      for (var i = 0; i < 24; i++)
        cache.write(path, _payload(i.isEven ? 0xAA : 0xBB)),
    ]);
    writing = false;
    await watcher;

    expect(sawEmpty, isFalse, reason: 'an entry is only ever seen complete');

    final bytes = File(path).readAsBytesSync();
    expect(bytes.length, _size);
    expect(bytes.first, anyOf(0xAA, 0xBB));
  });

  test('a write leaves no temp file behind', () async {
    await Future.wait([
      for (var i = 0; i < 4; i++) cache.write(path, _payload(i)),
    ]);
    final leftovers =
        dir.listSync().where((e) => e.path.endsWith('.part')).toList();
    expect(leftovers, isEmpty);
  });

  group('isUsable', () {
    test('says no to a file that was never written', () async {
      expect(await cache.isUsable('${dir.path}/missing.jpg'), isFalse);
    });

    test('says no to a zero-length file', () async {
      // A write that opened the file and then never landed. It passes an
      // exists() check and only fails once the decoder has it, which used to
      // cost a platform round trip *and* an exception on every pass.
      File(path).writeAsBytesSync(Uint8List(0));
      expect(await cache.isUsable(path), isFalse);
    });

    test('says no to a directory sitting where an entry should be', () async {
      Directory(path).createSync();
      expect(await cache.isUsable(path), isFalse);
    });
  });

  test('empty bytes are not worth an entry', () async {
    await cache.write(path, Uint8List(0));
    expect(File(path).existsSync(), isFalse);
  });
}
