import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/common_widgets/scroll_date_scrubber.dart';
import 'package:photo_map/core/theme/app_theme.dart';

const int _count = 100;
const double _rowHeight = 100;

/// Opacity the bubble is currently drawn at. It stays in the tree while hidden
/// so its text can outlive the fade, so presence alone proves nothing.
double _bubbleOpacity(WidgetTester tester) =>
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

void main() {
  testWidgets('the bubble names the span the viewport is over',
      (tester) async {
    final controller = await _pump(
      tester,
      labelFor: (first, last) => '$first..$last',
    );

    expect(_bubbleOpacity(tester), 0, reason: 'nothing has moved yet');

    // 800 logical into a 10000-tall list with an 800 viewport: rows 8 through 15.
    controller.jumpTo(800);
    await tester.pump();

    expect(_bubbleOpacity(tester), 1);
    expect(find.text('8..15'), findsOneWidget);
  });

  testWidgets('it gets out of the way once scrolling stops', (tester) async {
    final controller = await _pump(
      tester,
      labelFor: (first, last) => '$first..$last',
    );
    controller.jumpTo(800);
    await tester.pump();
    expect(_bubbleOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 2));
    expect(_bubbleOpacity(tester), 0);
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

    expect(_bubbleOpacity(tester), 0);
    expect(find.byType(RawScrollbar), findsOneWidget);
  });

  testWidgets('the thumb is draggable — the default on touch is not',
      (tester) async {
    await _pump(tester, labelFor: (a, b) => '$a..$b');
    expect(tester.widget<RawScrollbar>(find.byType(RawScrollbar)).interactive,
        isTrue);
  });

  testWidgets('the thumb starts level with the bubble', (tester) async {
    // The gallery floats a header over the top of the list. The thumb and the
    // bubble have to clear it by the same amount, or the thumb rides above the
    // date it is meant to be pointing at.
    const inset = EdgeInsets.only(top: 200, bottom: 24);
    final controller = await _pump(
      tester,
      labelFor: (a, b) => '$a..$b',
      padding: inset,
    );
    expect(
      tester.widget<RawScrollbar>(find.byType(RawScrollbar)).padding,
      inset,
      reason: 'the Material Scrollbar takes no padding, which was the bug',
    );

    // At the top of the list the bubble sits at the top of that inset track.
    controller.jumpTo(0);
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(AnimatedOpacity)).dy,
      greaterThanOrEqualTo(inset.top),
    );
  });
}
