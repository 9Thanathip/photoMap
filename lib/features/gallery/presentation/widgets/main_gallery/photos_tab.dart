import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/common_widgets/app_empty_state.dart';
import 'package:photo_map/common_widgets/photo_grid.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../providers/gallery_notifier.dart';
import '../../../utils/hue_sort.dart';
import 'photo_tile.dart';

enum ViewMode { all, year, month, day, hue }

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
    this.columns = kPhotoGridColumns,
    this.onColumns,
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

  /// Grid density. Pinching reports the new value through [onColumns]; passing
  /// no callback leaves the grid fixed.
  final int columns;
  final ValueChanged<int>? onColumns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isEmpty) {
      return AppEmptyState(
        icon: AppIcons.photo_library_outlined,
        title: l10n.noPhotosFound,
        subtitle: l10n.libraryEmpty,
      );
    }
    final months = l10n.monthsShort;
    final onColumns = this.onColumns;
    Widget grid(BuildContext context, ScrollController? c, ScrollPhysics? p) {
      return switch (viewMode) {
        ViewMode.all => _flatGrid(context, photos, c, p),
        ViewMode.hue => HueGrid(
          photos: photos,
          builder: (items) => _flatGrid(context, items, c, p),
        ),
        ViewMode.year => _sectionedGrid(
          _groupBy(photos, (p) => '${p.timestamp.year}'),
          (k) => k,
          context,
          c,
          p,
        ),
        ViewMode.month => _sectionedGrid(
          _groupBy(photos, (p) {
            final t = p.timestamp;
            return '${t.year}-${t.month.toString().padLeft(2, '0')}';
          }),
          (k) {
            final parts = k.split('-');
            return '${months[int.parse(parts[1]) - 1]} ${parts[0]}';
          },
          context,
          c,
          p,
        ),
        ViewMode.day => _sectionedGrid(
          _groupBy(photos, (p) {
            final t = p.timestamp;
            return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
          }),
          (k) {
            final parts = k.split('-');
            return '${int.parse(parts[2])} ${months[int.parse(parts[1]) - 1]} ${parts[0]}';
          },
          context,
          c,
          p,
        ),
      };
    }

    if (onColumns == null) return grid(context, null, null);
    return GridPinchZoom(columns: columns, onColumns: onColumns, builder: grid);
  }

  Map<String, List<PhotoItem>> _groupBy(
    List<PhotoItem> items,
    String Function(PhotoItem) key,
  ) {
    final map = <String, List<PhotoItem>>{};
    for (final p in items) {
      map.putIfAbsent(key(p), () => []).add(p);
    }
    return map;
  }

  /// Wraps a grid so the platform starts preparing the photos it is heading
  /// towards. [order] must be the order tiles actually appear in, which is not
  /// [photos] for the hue and sectioned views.
  Widget _prefetching(
    BuildContext context,
    List<PhotoItem> order,
    Widget child,
  ) => GridPrefetch(
    itemCount: order.length,
    assetAt: (i) => order[i].assetEntity,
    thumbSize: photoTileThumbSize(context, columns),
    child: child,
  );

  Widget _flatGrid(
    BuildContext context,
    List<PhotoItem> items,
    ScrollController? controller,
    ScrollPhysics? physics,
  ) {
    return _prefetching(
      context,
      items,
      GridView.builder(
        controller: controller,
        physics: physics,
        padding: EdgeInsets.only(top: contentTopPad, bottom: 120),
        gridDelegate: photoGridDelegate(columns),
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
            onLongPress: isSelectMode ? () {} : () => onLongPress(item),
          );
        },
      ),
    );
  }

  Widget _sectionedGrid(
    Map<String, List<PhotoItem>> sections,
    String Function(String) label,
    BuildContext context,
    ScrollController? controller,
    ScrollPhysics? physics,
  ) {
    final theme = Theme.of(context);
    final sortedKeys = sections.keys.toList()..sort((a, b) => b.compareTo(a));

    // Flatten in display order so the viewer can swipe across sections.
    final flat = <PhotoItem>[for (final key in sortedKeys) ...sections[key]!];
    final offsets = <String, int>{};
    var running = 0;
    for (final key in sortedKeys) {
      offsets[key] = running;
      running += sections[key]!.length;
    }

    return _prefetching(
      context,
      flat,
      CustomScrollView(
        controller: controller,
        physics: physics,
        slivers: [
          SliverPadding(padding: EdgeInsets.only(top: contentTopPad)),
          for (final key in sortedKeys) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                child: Text(
                  label(key),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: photoGridDelegate(columns),
              delegate: SliverChildBuilderDelegate((_, i) {
                final sectionPhotos = sections[key]!;
                final item = sectionPhotos[i];
                final globalIndex = offsets[key]! + i;
                return PhotoTile(
                  photo: item,
                  isSelectMode: isSelectMode,
                  isSelected: selectedPaths.contains(item.path),
                  onTap: isSelectMode
                      ? () => onToggleSelect!(item)
                      : () => onTap(flat, globalIndex),
                  onLongPress: isSelectMode ? () {} : () => onLongPress(item),
                );
              }, childCount: sections[key]!.length),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}

/// Async wrapper for the hue view: sorts (and tone-computes) off the build
/// path, showing progress on the first pass over a large library. Once the
/// tone cache is warm the sort is effectively instant.
class HueGrid extends StatefulWidget {
  const HueGrid({super.key, required this.photos, required this.builder});

  final List<PhotoItem> photos;
  final Widget Function(List<PhotoItem>) builder;

  @override
  State<HueGrid> createState() => _HueGridState();
}

class _HueGridState extends State<HueGrid> {
  List<PhotoItem>? _sorted;
  double _progress = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _sort();
  }

  @override
  void didUpdateWidget(HueGrid old) {
    super.didUpdateWidget(old);
    if (!identical(old.photos, widget.photos)) {
      _sort();
    }
  }

  Future<void> _sort() async {
    final gen = ++_generation;
    final sorted = await HueSortCache.sortByHue(
      widget.photos,
      onProgress: (p) {
        if (mounted && gen == _generation) {
          setState(() => _progress = p);
        }
      },
    );
    // A newer sort may have started while this one was computing.
    if (mounted && gen == _generation) {
      setState(() => _sorted = sorted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    if (sorted == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: _progress > 0 ? _progress : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).viewModeHueSorting,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return widget.builder(sorted);
  }
}
