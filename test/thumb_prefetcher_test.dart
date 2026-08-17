import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/core/services/thumb_prefetcher.dart';

const _size = ThumbnailSize.square(400);

List<AssetEntity> _band(int start) => [
      for (var i = start; i < start + 20; i++)
        AssetEntity(id: 'a$i', typeInt: 1, width: 10, height: 10),
    ];

void main() {
  final prefetcher = ThumbPrefetcher.instance;

  // Also called at the end of each body: the binding checks for stray timers
  // before tearDown runs, and the rate limiter always leaves one armed.
  setUp(prefetcher.resetForTest);

  testWidgets('warming starts on the first notification, not after the fling',
      (tester) async {
    // The bug this guards. A fling emits a scroll notification every frame; the
    // trailing debounce this replaced was cancelled by each of them, so nothing
    // was ever warmed *during* a fast scroll — only once it had stopped, which
    // is exactly when the tiles no longer needed it. That is what left a
    // screenful of empty frames behind a fast flick.
    final warmed = <int>[];
    var frame = 0;

    prefetcher.warm(_band(frame), _size, onReady: (a) => warmed.add(frame));
    expect(warmed, [0], reason: 'the very first frame of a fling warms');

    // Sixty more frames of a fling, one every 16ms — none of them idle long
    // enough for a trailing debounce to ever fire.
    for (var i = 0; i < 60; i++) {
      frame++;
      prefetcher.warm(_band(frame), _size, onReady: (a) => warmed.add(frame));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      warmed.length,
      greaterThan(1),
      reason: 'warming keeps up while the list is still moving',
    );
    // Rate-limited, though: ~960ms of scrolling at one round per 120ms.
    expect(warmed.length, lessThan(12));
    prefetcher.resetForTest();
  });

  testWidgets('the last position is never skipped', (tester) async {
    final warmed = <int>[];

    prefetcher.warm(_band(0), _size, onReady: (_) => warmed.add(0));
    // Arrives inside the cooldown, and is the position the user stopped at.
    prefetcher.warm(_band(1), _size, onReady: (_) => warmed.add(1));
    expect(warmed, [0], reason: 'held back by the rate limit');

    await tester.pump(const Duration(milliseconds: 130));
    expect(warmed, [0, 1], reason: 'and released once the gap has passed');
    prefetcher.resetForTest();
  });

  testWidgets('a range that has not moved is not warmed twice',
      (tester) async {
    var rounds = 0;
    prefetcher.warm(_band(0), _size, onReady: (_) => rounds++);
    await tester.pump(const Duration(milliseconds: 130));
    prefetcher.warm(_band(0), _size, onReady: (_) => rounds++);
    await tester.pump(const Duration(milliseconds: 130));
    expect(rounds, 1);
    prefetcher.resetForTest();
  });
}
