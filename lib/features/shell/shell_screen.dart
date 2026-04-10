import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_select_provider.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final select = ref.watch(gallerySelectProvider);
    // Only show delete bar when on the gallery tab (index 0) and in select mode
    final showDeleteBar =
        select.isSelectMode && navigationShell.currentIndex == 0;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: showDeleteBar
          ? _DeleteActionBar(
              selectedCount: select.selectedCount,
              onDelete: select.selectedCount > 0
                  ? () => _confirmDelete(context, ref, select)
                  : null,
            )
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Gallery',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.location_city_outlined),
                  selectedIcon: Icon(Icons.location_city),
                  label: 'Province',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, GallerySelectState select) {
    showDialog<void>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text('Delete ${select.selectedCount} photos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(dlg);
              ref
                  .read(galleryStateProvider.notifier)
                  .removePhotos(select.selectedPaths.toList());
              ref.read(gallerySelectProvider.notifier).exit();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DeleteActionBar extends StatelessWidget {
  const _DeleteActionBar({
    required this.selectedCount,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: onDelete != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface.withAlpha(60),
                ),
                iconSize: 28,
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
