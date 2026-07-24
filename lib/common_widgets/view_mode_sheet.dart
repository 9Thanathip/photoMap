import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photos_tab.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';

/// Shows a bottom sheet for selecting a [ViewMode].
/// Call this from any screen that needs a view mode filter.
void showViewModeSheet(
  BuildContext context, {
  required ViewMode current,
  required ValueChanged<ViewMode> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent, // Background transparent for custom design
    elevation: 0,
    isScrollControlled: true,
    builder: (_) => _ViewModeSheet(current: current, onSelected: onSelected),
  );
}

class _ViewModeSheet extends StatelessWidget {
  const _ViewModeSheet({
    required this.current,
    required this.onSelected,
  });

  final ViewMode current;
  final ValueChanged<ViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final botPad = MediaQuery.paddingOf(context).bottom;

    // Floating glass card, iOS style — detached from the screen edge so the
    // blur reads against the content behind it.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, botPad + 16),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetHandle(title: l10n.viewModeTitle),
            ...ViewMode.values.map(
              (v) => ListTile(
                title: Text(
                  l10n.viewModeLabel(v),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: current == v
                    ? Icon(AppIcons.check_rounded, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  onSelected(v);
                },
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}
