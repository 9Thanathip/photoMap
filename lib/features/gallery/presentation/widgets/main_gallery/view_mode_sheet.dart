import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photos_tab.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';

class ViewModeSheet extends StatelessWidget {
  const ViewModeSheet({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
  });

  final ViewMode currentMode;
  final ValueChanged<ViewMode> onModeSelected;

  static void show(
    BuildContext context, {
    required ViewMode currentMode,
    required ValueChanged<ViewMode> onModeSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ViewModeSheet(
        currentMode: currentMode,
        onModeSelected: onModeSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final botPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, botPad + 16),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetHandle(title: l10n.viewModeTitle),
            ...ViewMode.values.map(
              (m) => ListTile(
                title: Text(l10n.viewModeLabel(m),
                    style: GoogleFonts.poppins(fontSize: 14)),
                trailing: currentMode == m
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  onModeSelected(m);
                  Navigator.pop(context);
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
