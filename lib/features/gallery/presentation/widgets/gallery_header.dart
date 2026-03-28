import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

class GalleryHeader extends StatelessWidget {
  const GalleryHeader({
    super.key,
    required this.topPad,
    required this.inAlbumsTab,
    required this.inCountry,
    required this.inProvince,
    required this.selectedCountry,
    required this.selectedProvince,
    required this.onPhotoTab,
    required this.onAlbumTab,
    required this.onBack,
    required this.onFilterTap,
    this.isSelectMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onEnterSelect,
    required this.onCancelSelect,
    required this.onSelectAll,
  });

  final double topPad;
  final bool inAlbumsTab;
  final bool inCountry;
  final bool inProvince;
  final String selectedCountry;
  final String selectedProvince;
  final VoidCallback onPhotoTab;
  final VoidCallback onAlbumTab;
  final VoidCallback onBack;
  final VoidCallback onFilterTap;
  final bool isSelectMode;
  final int selectedCount;
  final int totalCount;
  final VoidCallback? onEnterSelect;
  final VoidCallback onCancelSelect;
  final VoidCallback onSelectAll;

  bool get _showBack => inAlbumsTab && inCountry;

  String get _title {
    if (inAlbumsTab && inProvince) return selectedProvince;
    if (inAlbumsTab && inCountry) return selectedCountry;
    return 'Gallery';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isSelectMode) {
      return Padding(
        padding: EdgeInsets.only(
            top: topPad + 6, left: 8, right: 8, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: onSelectAll,
                  child: Text(
                    selectedCount == totalCount && totalCount > 0
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
                Expanded(
                  child: Text(
                    selectedCount == 0
                        ? 'Select Items'
                        : '$selectedCount Selected',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: onCancelSelect,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding:
          EdgeInsets.only(top: topPad + 6, left: 16, right: 8, bottom: 6),
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
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: theme.colorScheme.primary),
                ),
                const Gap(6),
              ],
              Expanded(
                child: Text(
                  _title,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (!_showBack)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded),
                      color: theme.colorScheme.onSurface,
                      onPressed: onFilterTap,
                    ),
                    if (onEnterSelect != null)
                      TextButton(
                        onPressed: onEnterSelect,
                        child: const Text('Select'),
                      ),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  color: theme.colorScheme.onSurface,
                  onPressed: onFilterTap,
                ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 2),
              _TabToggle(
                  label: 'Photos', selected: !inAlbumsTab, onTap: onPhotoTab),
              const SizedBox(width: 18),
              _TabToggle(
                  label: 'Albums', selected: inAlbumsTab, onTap: onAlbumTab),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withAlpha(100),
        ),
      ),
    );
  }
}
