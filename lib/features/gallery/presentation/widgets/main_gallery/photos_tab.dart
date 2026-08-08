import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/common_widgets/app_empty_state.dart';
import 'package:photo_map/common_widgets/asset_thumb.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../providers/gallery_notifier.dart';
import '../../../utils/hue_sort.dart';
import 'photo_tile.dart';

enum ViewMode { all, year, month, day, hue }

const kPhotoGridColumns = 3;
const kPhotoGridSpacing = 1.5;

/// Upper bound for a grid tile's decode. Tiles are ~130pt, so this only ever
/// bites on very large displays.
const kPhotoTileMaxPixels = 800;

const photoGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: kPhotoGridColumns,
  crossAxisSpacing: kPhotoGridSpacing,
  mainAxisSpacing: kPhotoGridSpacing,
);

/// The exact pixel size a grid tile asks for.
///
/// The viewer reuses it for its placeholder and Hero flight image: a different
/// size is a different cache key, so asking for anything else starts a fresh
/// decode in the middle of the open animation — which is precisely when there
/// is no budget for one.
ThumbnailSize photoTileThumbSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final tile =
      (width - kPhotoGridSpacing * (kPhotoGridColumns - 1)) / kPhotoGridColumns;
  return assetThumbPx(context, Size(tile, tile),
      maxPixels: kPhotoTileMaxPixels);
}

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isEmpty) {
      return AppEmptyState(
          icon: AppIcons.photo_library_outlined,
          title: l10n.noPhotosFound,
          subtitle: l10n.libraryEmpty);
    }
    final months = l10n.monthsShort;
    return switch (viewMode) {
      ViewMode.all => _flatGrid(photos),
      ViewMode.hue => HueGrid(
          photos: photos,
          builder: _flatGrid,
        ),
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
            return '${months[int.parse(parts[1]) - 1]} ${parts[0]}';
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
            return '${int.parse(parts[2])} ${months[int.parse(parts[1]) - 1]} ${parts[0]}';
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

    // Flatten in display order so the viewer can swipe across sections.
    final flat = <PhotoItem>[
      for (final key in sortedKeys) ...sections[key]!,
    ];
    final offsets = <String, int>{};
    var running = 0;
    for (final key in sortedKeys) {
      offsets[key] = running;
      running += sections[key]!.length;
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: contentTopPad)),
        for (final key in sortedKeys) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
              child: Text(label(key),
                  style: TextStyle(
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
                final globalIndex = offsets[key]! + i;
                return PhotoTile(
                  photo: item,
                  isSelectMode: isSelectMode,
                  isSelected: selectedPaths.contains(item.path),
                  onTap: isSelectMode
                      ? () => onToggleSelect!(item)
                      : () => onTap(flat, globalIndex),
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
