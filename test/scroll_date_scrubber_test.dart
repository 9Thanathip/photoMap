import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/common_widgets/scroll_date_scrubber.dart';
import 'package:photo_map/core/theme/app_theme.dart';

const int _count = 100;
const double _rowHeight = 100;

/// Opacity the scrubber is currently drawn at. Both the thumb and the pill stay
/// in the tree while hidden — the pill so its text can outlive the fade — so
/// presence alone proves nothing.
double _opacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

Future<ScrollController> _pump(
  WidgetTester tester, {
  String? Function(int first, int last)? labelFor,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);

  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ScrollDateScrubber(
          controller: controller,
          itemCount: _count,
          labelFor: labelFor,
          padding: padding,
          child: ListView.builder(
            controller: controller,
            itemCount: _count,
            itemBuilder: (_, i) => SizedBox(height: _rowHeight),
          ),
        ),
      ),
    ),
  );
  return controller;
}

/// Grabs the thumb and drags it by [dy], in two steps: the first move a drag
/// recognizer sees is spent winning the gesture arena.
Future<void> _dragThumb(WidgetTester tester, double dy) async {
  final thumb = tester.getCenter(find.byKey(kScrubberThumbKey));
  final gesture = await tester.startGesture(thumb);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveBy(Offset(0, dy / 2));
  await tester.pump();
  await gesture.moveBy(Offset(0, dy / 2));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bubble names the span the viewport is over',
      (tester) async {
    final controller = await _pump(
      tester,
      labelFor: (first, last) => '$first..$last',
    );

    expect(_opacity(tester), 0, reason: 'nothing has moved yet');

    // 800 logical into a 10000-tall list with an 800 viewport: rows 8 through 15.
    controller.jumpTo(800);
    await tester.pump();

    expect(_opacity(tester), 1);
    expect(find.text('8..15'), findsOneWidget);
  });

  testWidgets('it gets out of the way once scrolling stops', (tester) async {
    final controller = await _pump(
      tester,
      labelFor: (first, last) => '$first..$last',
    );
    controller.jumpTo(800);
    await tester.pump();
    expect(_opacity(tester), 1);

    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 0);
    // The text is still there underneath: dropping it would blank the pill
    // before it had finished fading.
    expect(find.text('8..15'), findsOneWidget);
  });

  testWidgets('an order with no dates keeps the thumb and drops the bubble',
      (tester) async {
    // The hue view is sorted by colour, so a date span over it would be the
    // whole library at every scroll position.
    final controller = await _pump(tester);
    controller.jumpTo(800);
    await tester.pump();

    expect(find.byKey(kScrubberThumbKey), findsOneWidget);
    expect(_opacity(tester), 1, reason: 'the thumb still has to be draggable');
    expect(find.byKey(kScrubberBubbleKey), findsNothing);
  });

  testWidgets('dragging the thumb scrolls the list', (tester) async {
    // The framework leaves scrollbars non-interactive on touch, which for a
    // library this size means flinging for minutes.
    final controller = await _pump(tester, labelFor: (a, b) => '$a..$b');
    controller.jumpTo(800);
    await tester.pump();

    await _dragThumb(tester, 200);

    // 200pt down a 736pt run of track, over a 9200pt scroll.
    expect(controller.offset, closeTo(800 + (200 / 736) * 9200, 1));
  });

  testWidgets('dragging past the top does not push the list off screen',
      (tester) async {
    // Runs on iOS because that is where it bit: iOS physics bounce, and the
    // framework lets a *scrollbar* drag ride that bounce with no bound
    // (scrollbar.dart, _getPrimaryDelta clamps on desktop only). Overshooting
    // the top of the track by a finger's width took this list to -12000pt —
    // every row gone off the bottom of the screen.
    final controller = await _pump(tester, labelFor: (a, b) => '$a..$b');
    controller.jumpTo(800);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(kScrubberThumbKey)),
    );
    // Time has to pass, not just a frame: the press is recognized on a timer.
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, -400));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -400));
    await tester.pump();

    // Dragging up scrolls up — if this fails the gesture missed the thumb and
    // dragged the list instead, and the bound below proves nothing.
    expect(controller.offset, lessThan(800));
    expect(controller.offset, 0);

    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the bubble points at the thumb, wherever it is', (tester) async {
    // Two different equations over the same fraction was the old bug: the thumb
    // travelled `track - thumbHeight` while the pill travelled
    // `track - pillHeight`, so they only agreed in the middle.
    final controller = await _pump(tester, labelFor: (a, b) => '$a..$b');
    // Nothing is drawn until the list has moved at least once, and jumping to
    // where it already is reports no movement.
    controller.jumpTo(100);
    await tester.pump();

    for (final offset in [0.0, 800.0, 4600.0, 9200.0]) {
      controller.jumpTo(offset);
      await tester.pump();
      expect(
        tester.getCenter(find.byKey(kScrubberBubbleKey)).dy,
        closeTo(tester.getCenter(find.byKey(kScrubberThumbKey)).dy, 0.5),
        reason: 'at offset $offset',
      );
    }
  });

  testWidgets('both clear the floating header by the same inset',
      (tester) async {
    // The gallery floats a header over the top of the list. Anything drawn
    // above the padding is drawn behind that header.
    const inset = EdgeInsets.only(top: 200, bottom: 24);
    final controller = await _pump(
      tester,
      labelFor: (a, b) => '$a..$b',
      padding: inset,
    );

    controller.jumpTo(400);
    await tester.pump();
    controller.jumpTo(0);
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(kScrubberThumbKey)).dy,
      greaterThanOrEqualTo(inset.top),
    );
    expect(
      tester.getCenter(find.byKey(kScrubberBubbleKey)).dy,
      closeTo(tester.getCenter(find.byKey(kScrubberThumbKey)).dy, 0.5),
    );
  });
}
