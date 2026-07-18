import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photos_tab.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';

void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('AppL10nX.monthsShort', () {
    test('has 12 months in January-first order', () {
      expect(en.monthsShort.length, 12);
      expect(en.monthsShort.first, en.monthJan);
      expect(en.monthsShort.last, en.monthDec);
    });
  });

  group('AppL10nX.weekdaysFull', () {
    test('has 7 days, Monday-first (matches DateTime.weekday - 1)', () {
      expect(en.weekdaysFull.length, 7);
      expect(en.weekdaysFull.first, en.weekdayMon);
      // DateTime(2024,1,1) is a Monday -> index 0
      final monday = DateTime(2024, 1, 1);
      expect(en.weekdaysFull[monday.weekday - 1], en.weekdayMon);
    });
  });

  group('AppL10nX.viewModeLabel', () {
    test('maps every mode to its label', () {
      expect(en.viewModeLabel(ViewMode.all), en.viewModeAll);
      expect(en.viewModeLabel(ViewMode.year), en.viewModeYear);
      expect(en.viewModeLabel(ViewMode.month), en.viewModeMonth);
      expect(en.viewModeLabel(ViewMode.day), en.viewModeDay);
    });
  });

  group('AppL10nX.filmPresetName', () {
    test('known preset ids map to localized names', () {
      expect(en.filmPresetName('O', 'x'), en.presetOriginal);
      expect(en.filmPresetName('M5', 'x'), en.presetVintage);
      expect(en.filmPresetName('B1', 'x'), en.presetBw);
    });

    test('unknown id returns the fallback', () {
      expect(en.filmPresetName('ZZ', 'my-fallback'), 'my-fallback');
    });
  });
}
