import 'package:flutter/material.dart';
import 'package:photo_map/features/gallery/presentation/widgets/photos_tab.dart';

/// Shows a bottom sheet for selecting a [ViewMode].
/// Call this from any screen that needs a view mode filter.
void showViewModeSheet(
  BuildContext context, {
  required ViewMode current,
  required ValueChanged<ViewMode> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'View Mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...ViewMode.values.map(
            (v) => ListTile(
              title: Text(v.label),
              trailing: current == v
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelected(v);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
