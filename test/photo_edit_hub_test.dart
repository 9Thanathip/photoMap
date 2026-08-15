import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/core/theme/app_theme.dart';
import 'package:photo_map/features/auth/data/mock_auth_repository.dart';
import 'package:photo_map/features/auth/presentation/providers/auth_provider.dart';
import 'package:photo_map/features/gallery/presentation/screens/photo_edit_hub_screen.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photo_picker_sheet.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/app_localizations_en.dart';

Future<void> _pumpHub(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // The gallery notifier loads the device library only once auth reports
      // a signed-in user; the mock repository never does, so the hub comes up
      // with an empty library and no platform calls.
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PhotoEditHubScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('the hub lists every single-photo editor', (tester) async {
    await _pumpHub(tester);
    expect(find.text(l10n.editHubAdjust), findsOneWidget);
    expect(find.text(l10n.editHubCollage), findsOneWidget);
    expect(find.text(l10n.editHubExif), findsOneWidget);
  });

  testWidgets('choosing a feature asks for the photo', (tester) async {
    await _pumpHub(tester);
    // Feature first, photo second — the point of the screen. Nothing should
    // navigate until a photo has been named.
    expect(find.byType(PhotoPickerSheet), findsNothing);

    await tester.tap(find.text(l10n.editHubExif));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoPickerSheet), findsOneWidget);
  });

  testWidgets('dismissing the picker leaves the user on the hub',
      (tester) async {
    await _pumpHub(tester);
    await tester.tap(find.text(l10n.editHubAdjust));
    await tester.pumpAndSettle();

    // Tapping the scrim above the sheet is how a bottom sheet is dismissed.
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoPickerSheet), findsNothing);
    expect(find.text(l10n.editHubTitle), findsOneWidget);
  });

  testWidgets('the picker has its own way out', (tester) async {
    await _pumpHub(tester);
    await tester.tap(find.text(l10n.editHubAdjust));
    await tester.pumpAndSettle();

    // The sheet covers most of the screen, so the scrim above it is a stretch
    // from the thumb — the button is the reachable exit.
    // Scoped: the hub behind the sheet has a Cancel of its own.
    await tester.tap(find.descendant(
      of: find.byType(PhotoPickerSheet),
      matching: find.text(l10n.commonCancel),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoPickerSheet), findsNothing);
    expect(find.text(l10n.editHubTitle), findsOneWidget);
  });

  testWidgets('collage skips the picker — it fills its own cells',
      (tester) async {
    await _pumpHub(tester);
    await tester.tap(find.text(l10n.editHubCollage));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoPickerSheet), findsNothing);
    expect(find.text(l10n.collageTitle), findsOneWidget);
  });
}
