import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:gap/gap.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/common_widgets/top_scrim.dart';
import 'package:photo_map/l10n/app_localizations.dart';

class GalleryHeader extends StatelessWidget {
  const GalleryHeader({
    super.key,
    required this.topPad,
    required this.scrim,
    required this.inAlbumsTab,
    required this.inCountry,
    required this.inProvince,
    required this.selectedCountry,
    required this.selectedProvince,
    required this.onPhotoTab,
    required this.onAlbumTab,
    required this.onBack,
    required this.onFilterTap,
    this.onEditTap,
    this.isSelectMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onEnterSelect,
    required this.onCancelSelect,
    required this.onSelectAll,
  });

  final double topPad;

  /// Strength of the screen's top scrim, 0 → 1. Bare (non-glass) header
  /// content is drawn on top of it, so its colour has to travel with it —
  /// dark type at rest, light type once the scrim has darkened.
  final ValueListenable<double> scrim;

  final bool inAlbumsTab;
  final bool inCountry;
  final bool inProvince;
  final String selectedCountry;
  final String selectedProvince;
  final VoidCallback onPhotoTab;
  final VoidCallback onAlbumTab;
  final VoidCallback onBack;
  final VoidCallback onFilterTap;
  /// Opens the editing hub — where the collage builder now lives too. Null
  /// hides the button.
  final VoidCallback? onEditTap;
  final bool isSelectMode;
  final int selectedCount;
  final int totalCount;
  final VoidCallback? onEnterSelect;
  final VoidCallback onCancelSelect;
  final VoidCallback onSelectAll;

  bool get _showBack => inAlbumsTab && inCountry;

  String _titleText(AppLocalizations l10n) {
    if (inAlbumsTab && inProvince) return selectedProvince;
    if (inAlbumsTab && inCountry) return selectedCountry;
    return l10n.galleryTitle;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scrim,
      builder: (context, t, _) => _build(context, t),
    );
  }

  Widget _build(BuildContext context, double scrimT) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = _titleText(l10n);
    final fg = topScrimForeground(context, scrimT);

    if (isSelectMode) {
      return Padding(
        padding: EdgeInsets.only(top: topPad + 6, left: 8, right: 8, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: onSelectAll,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text(
                    selectedCount == totalCount && totalCount > 0
                        ? l10n.deselectAll
                        : l10n.selectAll,
                  ),
                ),
                Expanded(
                  child: Text(
                    selectedCount == 0
                        ? l10n.selectItems
                        : l10n.selectedCount(selectedCount),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onCancelSelect,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text(l10n.commonCancel),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topPad + 6, left: 16, right: 16, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_showBack) ...[
                GestureDetector(
                  onTap: onBack,
                  child: Icon(
                    AppIcons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: fg,
                  ),
                ),
                const Gap(8),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Visibility(
                    visible: !inAlbumsTab || inProvince,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onEditTap != null) ...[
                          GlassCard(
                            onTap: onEditTap,
                            borderRadius: 100,
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              AppIcons.tune_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Gap(8),
                        ],
                        GlassCard(
                          onTap: onFilterTap,
                          borderRadius: 100,
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            AppIcons.filter_list_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Gap(8),
                        if (onEnterSelect != null)
                          GlassCard(
                            onTap: onEnterSelect,
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(
                              l10n.commonSelect,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 2),
              _TabToggle(
                label: l10n.tabPhotos,
                selected: !inAlbumsTab,
                onTap: onPhotoTab,
                color: fg,
              ),
              const SizedBox(width: 18),
              _TabToggle(
                label: l10n.tabAlbums,
                selected: inAlbumsTab,
                onTap: onAlbumTab,
                color: fg,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  const _TabToggle({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? color : color.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
