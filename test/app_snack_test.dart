import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/common_widgets/app_snack.dart';
import 'package:photo_map/core/theme/app_theme.dart';

/// Hosts the app the way the real one is arranged: toasts go on the root
/// overlay, which sits above every route and therefore above every [Material].
Future<BuildContext> _host(WidgetTester tester) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
  return hostContext;
}

/// Lets the toast live out its dwell time. Without this the auto-dismiss timer
/// is still armed when the test ends, which the binding reports as a failure.
Future<void> _expire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toast text is not underlined', (tester) async {
    // An overlay entry has no Material above it, and without one Flutter falls
    // back to its error text style — a yellow double underline under every
    // toast the app has ever shown, "Saved to Photos" included.
    final context = await _host(tester);
    AppSnack.success(context, 'Saved to Photos');
    await tester.pumpAndSettle();

    final style = DefaultTextStyle.of(
      tester.element(find.text('Saved to Photos')),
    ).style;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);

    await _expire(tester);
  });

  testWidgets('a second toast replaces the first rather than stacking',
      (tester) async {
    final context = await _host(tester);
    AppSnack.success(context, 'Saved to Photos');
    await tester.pumpAndSettle();
    AppSnack.error(context, 'Failed to save image');
    await tester.pumpAndSettle();

    expect(find.text('Saved to Photos'), findsNothing);
    expect(find.text('Failed to save image'), findsOneWidget);

    await _expire(tester);
  });
}
