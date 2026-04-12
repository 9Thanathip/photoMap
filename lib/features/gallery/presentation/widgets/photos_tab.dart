import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/common_widgets/app_empty_state.dart';
import '../providers/gallery_notifier.dart';
import 'photo_tile.dart';

enum ViewMode { all, year, month, day }

extension ViewModeLabel on ViewMode {
  String get label => switch (this) {
        ViewMode.all => 'All',
        ViewMode.year => 'Year',
        ViewMode.month => 'Month',
        ViewMode.day => 'Day',
      };
}

const photoGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 1.5,
  mainAxisSpacing: 1.5,
);

class PhotosTab extends StatelessWidget {
  const PhotosTab({
    super.key,
    required this.photos,
    required this.viewMode,
    required this.contentTopPad,
    required this.isEmpty,
    required this.onTap,
    required this.onLongPress,
    this.isSelectMode = false,
    this.selectedPaths = const {},
    this.onToggleSelect,
  });

  final List<PhotoItem> photos;
  final ViewMode viewMode;
  final double contentTopPad;
  final bool isEmpty;
  final void Function(List<PhotoItem> photos, int index) onTap;
  final void Function(PhotoItem) onLongPress;
  final bool isSelectMode;
  final Set<String> selectedPaths;
  final void Function(PhotoItem)? onToggleSelect;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return const AppEmptyState(
          icon: Icons.photo_library_outlined,
          title: 'No photos found',
          subtitle: 'Your photo library is empty');
    }
    return switch (viewMode) {
      ViewMode.all => _flatGrid(photos),
      ViewMode.year => _sectionedGrid(
          _groupBy(photos, (p) => '${p.timestamp.year}'),
          (k) => k,
          context,
        ),
      ViewMode.month => _sectionedGrid(
          _groupBy(photos, (p) {
            final t = p.timestamp;
            return '${t.year}-${t.month.toString().padLeft(2, '0')}';
          }),
          (k) {
            final parts = k.split('-');
            return '${_months[int.parse(parts[1]) - 1]} ${parts[0]}';
          },
          context,
        ),
      ViewMode.day => _sectionedGrid(
          _groupBy(photos, (p) {
            final t = p.timestamp;
            return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
          }),
          (k) {
            final parts = k.split('-');
            return '${int.parse(parts[2])} ${_months[int.parse(parts[1]) - 1]} ${parts[0]}';
          },
          context,
        ),
    };
  }

  Map<String, List<PhotoItem>> _groupBy(
      List<PhotoItem> items, String Function(PhotoItem) key) {
    final map = <String, List<PhotoItem>>{};
    for (final p in items) {
      map.putIfAbsent(key(p), () => []).add(p);
    }
    return map;
  }

  Widget _flatGrid(List<PhotoItem> items) {
    return GridView.builder(
      padding: EdgeInsets.only(top: contentTopPad, bottom: 120),
      gridDelegate: photoGridDelegate,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return PhotoTile(
          photo: item,
          isSelectMode: isSelectMode,
          isSelected: selectedPaths.contains(item.path),
          onTap: isSelectMode
              ? () => onToggleSelect!(item)
              : () => onTap(items, i),
          onLongPress: isSelectMode
              ? () {}
              : () => onLongPress(item),
        );
      },
    );
  }

  Widget _sectionedGrid(Map<String, List<PhotoItem>> sections,
      String Function(String) label, BuildContext context) {
    final theme = Theme.of(context);
    final sortedKeys = sections.keys.toList()..sort((a, b) => b.compareTo(a));
    return CustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: contentTopPad)),
        for (final key in sortedKeys) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
              child: Text(label(key),
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ),
          ),
          SliverGrid(
            gridDelegate: photoGridDelegate,
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final sectionPhotos = sections[key]!;
                final item = sectionPhotos[i];
                return PhotoTile(
                  photo: item,
                  isSelectMode: isSelectMode,
                  isSelected: selectedPaths.contains(item.path),
                  onTap: isSelectMode
                      ? () => onToggleSelect!(item)
                      : () => onTap(sectionPhotos, i),
                  onLongPress: isSelectMode
                      ? () {}
                      : () => onLongPress(item),
                );
              },
              childCount: sections[key]!.length,
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }
}
