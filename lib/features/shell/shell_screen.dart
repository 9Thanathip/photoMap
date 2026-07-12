import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_select_provider.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final select = ref.watch(gallerySelectProvider);
    final showDeleteBar = select.isSelectMode && navigationShell.currentIndex == 0;
    final botPad = MediaQuery.paddingOf(context).bottom;
    final safeBot = botPad > 0 ? botPad : 16.0;

    return Scaffold(
          extendBody: true,
          body: navigationShell,
          bottomNavigationBar: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, safeBot),
        child: showDeleteBar
            ? GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _DeleteActionBar(
                  selectedCount: select.selectedCount,
                  onDelete: select.selectedCount > 0
                      ? () => _confirmDelete(context, ref, select)
                      : null,
                ),
              )
            : GlassCard(
                borderRadius: 28,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavIcon(
                      isSelected: navigationShell.currentIndex == 0,
                      icon: Icons.photo_library_outlined,
                      selectedIcon: Icons.photo_library,
                      label: l10n.galleryTitle,
                      onTap: () => _onTabSelected(0),
                    ),
                    _NavIcon(
                      isSelected: navigationShell.currentIndex == 1,
                      icon: Icons.map_outlined,
                      selectedIcon: Icons.map,
                      label: l10n.navMap,
                      onTap: () => _onTabSelected(1),
                    ),
                    _NavIcon(
                      isSelected: navigationShell.currentIndex == 2,
                      icon: Icons.emoji_events_outlined,
                      selectedIcon: Icons.emoji_events,
                      label: l10n.navAchievements,
                      onTap: () => _onTabSelected(2),
                    ),
                    _NavIcon(
                      isSelected: navigationShell.currentIndex == 3,
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: l10n.settingsTitle,
                      onTap: () => _onTabSelected(3),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, GallerySelectState select) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(l10n.deletePhotosTitle),
        content: Text(l10n.deletePhotosBody(select.selectedCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg),
            child: Text(l10n.commonCancel),
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
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.isSelected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool isSelected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final activeColor = t.textPrimary;
    final inactiveColor = t.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.15 : 1.0,
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$selectedCount selected',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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
    );
  }
}
