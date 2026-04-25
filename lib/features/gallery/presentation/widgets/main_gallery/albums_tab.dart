import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/common_widgets/app_empty_state.dart';
import '../../providers/gallery_notifier.dart';
import 'album_card.dart';
import 'photo_tile.dart';
import 'photos_tab.dart' show photoGridDelegate, ViewMode;

const _albumGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
  childAspectRatio: 0.92,
);

class AlbumsTab extends ConsumerStatefulWidget {
  const AlbumsTab({
    super.key,
    required this.gallery,
    required this.contentTopPad,
    required this.inCountry,
    required this.inProvince,
    required this.onTap,
    required this.onLongPress,
    this.viewMode = ViewMode.all,
    this.isSelectMode = false,
    this.selectedPaths = const {},
    this.onToggleSelect,
  });

  final GalleryState gallery;
  final double contentTopPad;
  final bool inCountry;
  final bool inProvince;
  final void Function(List<PhotoItem> photos, int index) onTap;
  final void Function(PhotoItem) onLongPress;
  final ViewMode viewMode;
  final bool isSelectMode;
  final Set<String> selectedPaths;
  final void Function(PhotoItem)? onToggleSelect;

  @override
  ConsumerState<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends ConsumerState<AlbumsTab> {
  bool _goingDeeper = true;

  // Swipe-back tracking
  double _dragX = 0;
  bool _isDragging = false;

  int _depthOf(bool inCountry, bool inProvince) =>
      inProvince ? 2 : (inCountry ? 1 : 0);

  @override
  void didUpdateWidget(AlbumsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldD = _depthOf(oldWidget.inCountry, oldWidget.inProvince);
    final newD = _depthOf(widget.inCountry, widget.inProvince);
    if (newD != oldD) _goingDeeper = newD > oldD;
  }

  void _goBack() {
    setState(() {
      _goingDeeper = false;
      _dragX = 0;
      _isDragging = false;
    });
    final notifier = ref.read(galleryStateProvider.notifier);
    if (widget.inProvince) {
      notifier.selectProvince('All');
    } else {
      notifier.selectCountry('All');
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.inCountry) return;
    // Only track rightward drag
    final newX = (_dragX + details.delta.dx).clamp(0.0, double.infinity);
    setState(() {
      _dragX = newX;
      _isDragging = true;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.inCountry) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final velocity = details.primaryVelocity ?? 0;
    final shouldGoBack =
        velocity > 400 || _dragX > screenWidth * 0.3;

    if (shouldGoBack) {
      _goBack();
    } else {
      setState(() {
        _dragX = 0;
        _isDragging = false;
      });
    }
  }

  void _onDragCancel() => setState(() {
        _dragX = 0;
        _isDragging = false;
      });

  @override
  Widget build(BuildContext context) {
    final Widget content;
    final String switchKey;

    if (widget.inProvince) {
      content = _provincePhotos();
      switchKey =
          'province:${widget.gallery.selectedCountry}:${widget.gallery.selectedProvince}';
    } else if (widget.inCountry) {
      content = _provincesGrid();
      switchKey = 'country:${widget.gallery.selectedCountry}';
    } else {
      content = _countriesGrid();
      switchKey = 'all';
    }

    Widget switcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey(switchKey);
        final Offset slideBegin;
        if (_goingDeeper) {
          slideBegin =
              isIncoming ? const Offset(0.07, 0) : const Offset(-0.07, 0);
        } else {
          slideBegin =
              isIncoming ? const Offset(-0.07, 0) : const Offset(0.07, 0);
        }
        return SlideTransition(
          position:
              Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(switchKey), child: content),
    );

    // Wrap with swipe-back gesture when inside an album
    if (widget.inCountry) {
      switcher = GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: AnimatedContainer(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_dragX * 0.35, 0, 0),
          child: switcher,
        ),
      );
    }

    return switcher;
  }

  Widget _countriesGrid() {
    final byCountry = widget.gallery.photosByCountry;
    if (byCountry.isEmpty) {
      return AppEmptyState(
        icon: Icons.photo_library_outlined,
        title: widget.gallery.isGeocoding
            ? 'Detecting locations...'
            : 'No photos found',
        subtitle:
            widget.gallery.isGeocoding ? 'Your photos will appear shortly' : '',
        showLoader: widget.gallery.isGeocoding,
      );
    }
    final names = byCountry.keys.where((k) => k != 'Unknown').toList()..sort();
    return GridView.builder(
      key: const PageStorageKey('albums_countries'),
      padding: EdgeInsets.fromLTRB(10, widget.contentTopPad, 10, 120),
      gridDelegate: _albumGridDelegate,
      itemCount: names.length,
      itemBuilder: (_, i) {
        final name = names[i];
        return AlbumCard(
          title: name,
          subtitle: '${byCountry[name]!.length} photos',
          coverPhoto: byCountry[name]!.first,
          onTap: () =>
              ref.read(galleryStateProvider.notifier).selectCountry(name),
        );
      },
    );
  }

  Widget _provincesGrid() {
    final byProvince =
        widget.gallery.photosByProvince(widget.gallery.selectedCountry);
    if (byProvince.isEmpty) {
      return AppEmptyState(
          icon: Icons.photo_library_outlined,
          title: 'No photos in ${widget.gallery.selectedCountry}',
          subtitle: '');
    }
    final names = byProvince.keys.toList()..sort();
    return GridView.builder(
      key: PageStorageKey('albums_provinces_${widget.gallery.selectedCountry}'),
      padding: EdgeInsets.fromLTRB(10, widget.contentTopPad, 10, 120),
      gridDelegate: _albumGridDelegate,
      itemCount: names.length,
      itemBuilder: (_, i) {
        final name = names[i];
        return AlbumCard(
          title: name,
          subtitle: '${byProvince[name]!.length} photos',
          coverPhoto: byProvince[name]!.first,
          onTap: () =>
              ref.read(galleryStateProvider.notifier).selectProvince(name),
        );
      },
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Map<String, List<PhotoItem>> _groupBy(
      List<PhotoItem> items, String Function(PhotoItem) key) {
    final map = <String, List<PhotoItem>>{};
    for (final p in items) {
      map.putIfAbsent(key(p), () => []).add(p);
    }
    return map;
  }

  Widget _provincePhotos() {
    final photos = widget.gallery.filteredPhotos;
    if (photos.isEmpty) {
      return const AppEmptyState(
          icon: Icons.photo_library_outlined,
          title: 'No photos here',
          subtitle: 'Your photo library is empty');
    }

    return switch (widget.viewMode) {
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

  Widget _flatGrid(List<PhotoItem> items) {
    return GridView.builder(
      padding: EdgeInsets.only(top: widget.contentTopPad, bottom: 120),
      gridDelegate: photoGridDelegate,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return PhotoTile(
          photo: item,
          isSelectMode: widget.isSelectMode,
          isSelected: widget.selectedPaths.contains(item.path),
          onTap: widget.isSelectMode
              ? () => widget.onToggleSelect!(item)
              : () => widget.onTap(items, i),
          onLongPress: widget.isSelectMode
              ? () {}
              : () => widget.onLongPress(item),
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
        SliverPadding(padding: EdgeInsets.only(top: widget.contentTopPad)),
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
                  isSelectMode: widget.isSelectMode,
                  isSelected: widget.selectedPaths.contains(item.path),
                  onTap: widget.isSelectMode
                      ? () => widget.onToggleSelect!(item)
                      : () => widget.onTap(sectionPhotos, i),
                  onLongPress: widget.isSelectMode
                      ? () {}
                      : () => widget.onLongPress(item),
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
