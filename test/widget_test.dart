import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/common_widgets/app_button.dart';
import 'package:photo_map/core/theme/app_theme.dart';

// The old smoke test pumped the full App(), which needs Firebase.initializeApp
// and fails under the test harness. This exercises a real reusable widget that
// has no platform dependencies instead.
Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('AppButton renders its label', (tester) async {
    await tester.pumpWidget(_wrap(AppButton(label: 'Save', onPressed: () {})));
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('AppButton fires onPressed on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(AppButton(label: 'Save', onPressed: () => taps++)),
    );
    await tester.tap(find.byType(AppButton));
    expect(taps, 1);
  });

  testWidgets('AppButton is disabled while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(AppButton(label: 'Save', loading: true, onPressed: () => taps++)),
    );
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(taps, 0);
  });
}
