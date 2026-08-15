import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/common_widgets/color_picker_sheet.dart';
import 'package:photo_map/core/theme/app_theme.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/app_localizations_en.dart';

const _presets = [
  ColorPreset('White', Colors.white),
  ColorPreset('Black', Colors.black),
];

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// Which half of the sheet is showing. Read off the crossfade rather than by
/// searching for a widget: it keeps *both* halves built at all times, so
/// anything found in the tree is there whichever one is visible.
CrossFadeState _half(WidgetTester tester) => tester
    .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
    .crossFadeState;

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Color current,
  bool startCustom = false,
}) async {
  // The sheet is a phone-height column; the default 800x600 test surface is
  // too short for it and would overflow.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _wrap(ColorPickerSheet(
      title: 'Background',
      current: current,
      presets: _presets,
      startCustom: startCustom,
      onSelect: (_) {},
    )),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the presets by default', (tester) async {
    await _pumpSheet(tester, current: Colors.white);
    expect(_half(tester), CrossFadeState.showFirst);
  });

  testWidgets('startCustom lands straight on the free colour editor',
      (tester) async {
    // For callers that already show the same presets on the screen behind the
    // sheet, where the grid would just be those choices a second time.
    await _pumpSheet(
      tester,
      current: const Color(0xFF3366CC),
      startCustom: true,
    );
    expect(_half(tester), CrossFadeState.showSecond);
    // Seeded from the colour in use, not from some default.
    expect(find.text('#3366CC'), findsOneWidget);
  });

  testWidgets('the presets are still reachable from the custom editor',
      (tester) async {
    await _pumpSheet(tester, current: Colors.white, startCustom: true);
    await tester.tap(find.text(AppLocalizationsEn().mapBackToPresets));
    await tester.pumpAndSettle();
    expect(_half(tester), CrossFadeState.showFirst);
  });
}
