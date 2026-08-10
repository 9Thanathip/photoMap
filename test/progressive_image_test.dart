import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/common_widgets/progressive_image.dart';

/// An image provider that stays pending until the test decides otherwise.
class _ManualImage extends ImageProvider<_ManualImage> {
  _ManualImage(this.name);

  final String name;
  final Completer<ImageInfo> _completer = Completer<ImageInfo>();

  /// How many times anything asked the platform for these bytes.
  int loads = 0;

  void complete(ui.Image image) => _completer.complete(ImageInfo(image: image));

  @override
  Future<_ManualImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ManualImage>(this);

  @override
  ImageStreamCompleter loadImage(_ManualImage key, ImageDecoderCallback decode) {
    loads++;
    return OneFrameImageStreamCompleter(_completer.future);
  }

  @override
  bool operator ==(Object other) => other is _ManualImage && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 100, height: 100, child: child),
    );

/// Decoding runs on a real thread, so it has to happen outside the test's fake
/// async zone or the future never completes.
Future<ui.Image> _image(WidgetTester tester, int side) async {
  final image = await tester.runAsync(
    () => createTestImage(width: side, height: side),
  );
  return image!;
}

void main() {
  testWidgets('preview covers the gap, then the sharp frame replaces it',
      (tester) async {
    final preview = _ManualImage('preview');
    final sharp = _ManualImage('sharp');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100,
          height: 100,
          child: ProgressiveImage(
            preview: preview,
            image: sharp,
            placeholder: const ColoredBox(key: Key('shimmer'), color: Colors.grey),
          ),
        ),
      ),
    );

    // Nothing decoded yet: the placeholder is all there is to show.
    expect(find.byKey(const Key('shimmer')), findsOneWidget);

    preview.complete(await _image(tester, 8));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('shimmer')), findsNothing,
        reason: 'the preview took over from the placeholder');
    expect(find.byType(Image), findsNWidgets(2),
        reason: 'preview underneath, sharp on top at zero opacity');

    sharp.complete(await _image(tester, 64));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    // Preview dropped once the crossfade finished — leaving it in the tree
    // would cost a second full fill of the tile on every frame.
    expect(find.byType(Image), findsOneWidget);
  });

  // The warm-up is what lets a preview load mid-fling at all: Image's
  // ScrollAwareImageProvider refuses to start work while a list is moving
  // fast, and only takes its early exit when the key is already cached. That
  // makes cancelling it on dispose load-bearing — a fling disposes hundreds of
  // rows, and none of them may leave a platform request behind.
  testWidgets('the preview warm-up does not outlive the tile', (tester) async {
    final preview = _ManualImage('warm-flies');
    final sharp = _ManualImage('warm-flies-sharp');

    await tester.pumpWidget(
      _host(ProgressiveImage(preview: preview, image: sharp)),
    );
    // Gone again well inside the warm-up window, the way a row is during a
    // fling. The test ends with the timer still armed if dispose forgot it,
    // which trips the framework's "A Timer is still pending" check.
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(_host(const SizedBox.shrink()));
  });

  testWidgets('regridding cross-fades instead of swapping', (tester) async {
    final preview = _ManualImage('regrid-preview');
    final before = _ManualImage('regrid-before');
    final after = _ManualImage('regrid-after');

    Widget at(ImageProvider sharp) =>
        _host(ProgressiveImage(preview: preview, image: sharp));

    await tester.pumpWidget(at(before));
    preview.complete(await _image(tester, 8));
    before.complete(await _image(tester, 64));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget,
        reason: 'settled on the first decode');

    // Pinching to a new density asks every tile for a differently sized decode.
    await tester.pumpWidget(at(after));
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image == before),
      findsOneWidget,
      reason: 'the old decode has to stay up as the thing being faded from',
    );
    expect(find.byType(Image), findsNWidgets(2));

    after.complete(await _image(tester, 96));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image == after),
      findsOneWidget,
    );
  });

  testWidgets('a sharp frame that never arrives leaves the preview showing',
      (tester) async {
    final preview = _ManualImage('preview-only');
    final sharp = _ManualImage('never');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100,
          height: 100,
          child: ProgressiveImage(preview: preview, image: sharp),
        ),
      ),
    );

    preview.complete(await _image(tester, 8));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(2));
  });
}
