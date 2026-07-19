import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import '../../providers/country_provider.dart';
import 'country_picker_sheet.dart';

class NationalMapHeader extends ConsumerWidget {
  const NationalMapHeader({super.key});

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CountryPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(countryProvider).current;
    final isThai = Localizations.localeOf(context).languageCode == 'th';
    final countryName = isThai && country.nameTh.isNotEmpty
        ? country.nameTh
        : country.nameEn;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : Colors.black.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.map_outlined,
              size: 15,
              color: iconColor,
            ),
            const SizedBox(width: 6),
            Text(
              countryName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              AppIcons.expand_more_rounded,
              size: 16,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
