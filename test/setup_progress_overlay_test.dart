import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/common_widgets/setup_progress_overlay.dart';
import 'package:photo_map/core/theme/app_theme.dart';
import 'package:photo_map/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int processed,
  required int total,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SetupProgressOverlay(processed: processed, total: total),
    ),
  );
  await tester.pumpAndSettle();
}

Color _barColour(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .valueColor!
    .value!;

void main() {
  testWidgets('it counts what has been indexed so far', (tester) async {
    await _pump(tester, processed: 250, total: 1000);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('nothing to count yet is not a division by zero',
      (tester) async {
    // geocodeTotal is 0 until the library has been walked, and the overlay is
    // on screen before that.
    await _pump(tester, processed: 0, total: 0);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('a finished pass reads 100, not 137', (tester) async {
    await _pump(tester, processed: 1200, total: 1000);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('it follows the theme instead of being white on black',
      (tester) async {
    // The overlay used to hardcode Colors.white throughout, which read as a
    // dark-mode dialog dropped into a light-mode app.
    await _pump(tester, processed: 1, total: 2, theme: AppTheme.light());
    final light = _barColour(tester);

    await _pump(tester, processed: 1, total: 2, theme: AppTheme.dark());
    final dark = _barColour(tester);

    expect(light, isNot(Colors.white));
    expect(dark, isNot(Colors.white));
  });
}
