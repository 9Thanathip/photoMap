import '../features/gallery/presentation/widgets/main_gallery/photos_tab.dart';
import 'app_localizations.dart';

/// Shared l10n helpers for values that appear in several screens
/// (month abbreviations, view-mode labels, film-preset names).
extension AppL10nX on AppLocalizations {
  /// Short month names, index 0 = January.
  List<String> get monthsShort => [
        monthJan,
        monthFeb,
        monthMar,
        monthApr,
        monthMay,
        monthJun,
        monthJul,
        monthAug,
        monthSep,
        monthOct,
        monthNov,
        monthDec,
      ];

  /// Full weekday names, index 0 = Monday (matches DateTime.weekday - 1).
  List<String> get weekdaysFull => [
        weekdayMon,
        weekdayTue,
        weekdayWed,
        weekdayThu,
        weekdayFri,
        weekdaySat,
        weekdaySun,
      ];

  /// "12 Feb – 15 Feb 2025", collapsed to one date when the range is a day.
  String dateRange(DateTime start, DateTime end) {
    final months = monthsShort;
    final from = '${start.day} ${months[start.month - 1]}';
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '$from ${start.year}';
    }
    return '$from – ${end.day} ${months[end.month - 1]} ${end.year}';
  }

  /// "3 days, 2 nights" — a day trip has no nights half to show.
  String tripStay(int days, int nights) =>
      nights > 0 ? tripDaysNights(days, nights) : tripDays(days);

  /// Same, sized for an itinerary chip.
  String tripStayShort(int days, int nights) =>
      nights > 0 ? tripDaysNightsShort(days, nights) : tripDaysShort(days);

  String viewModeLabel(ViewMode mode) => switch (mode) {
        ViewMode.all => viewModeAll,
        ViewMode.year => viewModeYear,
        ViewMode.month => viewModeMonth,
        ViewMode.day => viewModeDay,
        ViewMode.hue => viewModeHue,
      };

  /// Maps a [FilterPreset.id] to its localized display name.
  String filmPresetName(String id, String fallback) => switch (id) {
        'O' => presetOriginal,
        'F1' => presetMoody,
        'C1' => presetVibrant,
        'M5' => presetVintage,
        'P5' => presetPolaroid,
        'B1' => presetBw,
        _ => fallback,
      };
}
