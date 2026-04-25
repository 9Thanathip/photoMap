import 'package:flutter/material.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photos_tab.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';

/// Shows a bottom sheet for selecting a [ViewMode].
/// Call this from any screen that needs a view mode filter.
void showViewModeSheet(
  BuildContext context, {
  required ViewMode current,
  required ValueChanged<ViewMode> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent, // Background transparent for custom design
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
    final botPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHandle(title: 'View Mode'),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withAlpha(80),
          ),
          ...ViewMode.values.map(
            (v) => ListTile(
              title: Text(
                v.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              trailing: current == v
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelected(v);
              },
            ),
          ),
          SizedBox(height: botPad + 16),
        ],
      ),
    );
  }
}
