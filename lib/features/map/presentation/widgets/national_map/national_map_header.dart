import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import '../../providers/country_provider.dart';
import 'country_picker_sheet.dart';

class NationalMapHeader extends ConsumerWidget {
  const NationalMapHeader({super.key});

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const CountryPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(countryProvider).current;

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 15,
              color: Colors.black.withOpacity(0.55),
            ),
            const SizedBox(width: 6),
            Text(
              country.nameEn,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: Colors.black.withOpacity(0.55),
            ),
          ],
        ),
      ),
    );
  }
}
