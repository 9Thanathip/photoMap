import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/common_widgets/app_empty_state.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import '../../../gallery/presentation/providers/gallery_notifier.dart';
import '../../../gallery/presentation/widgets/photo_tile.dart';
import '../../../gallery/presentation/widgets/photo_viewer_screen.dart';
import '../../../gallery/presentation/widgets/photos_tab.dart';
import '../widgets/province_district/province_header.dart';
import 'package:photo_map/common_widgets/view_mode_sheet.dart';

class ProvinceGalleryScreen extends ConsumerStatefulWidget {
  const ProvinceGalleryScreen({
    super.key,
    required this.provinceName,
    this.onPickCover,
  });

  final String provinceName;
  /// When non-null, the screen operates in "pick cover" mode.
  /// Tapping a photo calls this callback instead of opening the viewer.
  final void Function(PhotoItem photo)? onPickCover;

  @override
  ConsumerState<ProvinceGalleryScreen> createState() =>
      _ProvinceGalleryScreenState();
}

class _ProvinceGalleryScreenState extends ConsumerState<ProvinceGalleryScreen> {
  ViewMode _viewMode = ViewMode.day;
  bool _isScrolled = false;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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

  String _getLabel(String k, ViewMode mode) {
    if (mode == ViewMode.year) return k;
    if (mode == ViewMode.month) {
      final parts = k.split('-');
      return '${_months[int.parse(parts[1]) - 1]} ${parts[0]}';
    }
    if (mode == ViewMode.day) {
      final parts = k.split('-');
      return '${int.parse(parts[2])} ${_months[int.parse(parts[1]) - 1]} ${parts[0]}';
    }
    return '';
  }

  void _showFilterSheet() {
    showViewModeSheet(
      context,
      current: _viewMode,
      onSelected: (v) => setState(() => _viewMode = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryStateProvider);
    final photos =
        gallery.allPhotos
            .where((p) => p.province == widget.provinceName)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final topPad = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

    final isPickMode = widget.onPickCover != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Content
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              final scrolled = n.metrics.pixels > 0;
              if (scrolled != _isScrolled) {
                setState(() => _isScrolled = scrolled);
              }
              return false;
            },
            child: Positioned.fill(
              child: photos.isEmpty
                  ? AppEmptyState(
                      icon: Icons.photo_library_outlined,
                      title: 'No photos in ${widget.provinceName}',
                      subtitle:
                          'Photos you take in this province will appear here.',
                    )
                  : _buildGrid(context, topPad, theme, photos),
            ),
          ),

          // Pick mode hint bar at top (below header)
          if (isPickMode)
            Positioned(
              top: topPad + 68,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Tap a photo to set as cover',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Header
          Positioned(
            top: topPad + 12,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ProvinceHeader(
                    title: widget.provinceName,
                    viewMode: ProvinceViewMode.grid,
                    isSelectingDistrict: true,
                    onBack: () => Navigator.pop(context),
                    onToggleMode: () {},
                  ),
                ),
                if (!isPickMode) ...[
                  const SizedBox(width: 8),
                  GlassCard(
                    borderRadius: 12,
                    padding: const EdgeInsets.all(8),
                    onTap: _showFilterSheet,
                    child: Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    double topPad,
    ThemeData theme,
    List<PhotoItem> photos,
  ) {
    final isPickMode = widget.onPickCover != null;
    void onTap(List<PhotoItem> list, int i) {
      if (isPickMode) {
        widget.onPickCover!(list[i]);
      } else {
        _openViewer(context, list, i);
      }
    }

    final extraTop = isPickMode ? 44.0 : 0.0;

    if (_viewMode == ViewMode.all) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(1.5, topPad + 88 + extraTop, 1.5, 32),
        gridDelegate: photoGridDelegate,
        itemCount: photos.length,
        itemBuilder: (_, i) => PhotoTile(
          photo: photos[i],
          onTap: () => onTap(photos, i),
          onLongPress: () {},
        ),
      );
    }

    final sections = _groupBy(photos, (p) {
      final t = p.timestamp;
      if (_viewMode == ViewMode.year) return '${t.year}';
      if (_viewMode == ViewMode.month) {
        return '${t.year}-${t.month.toString().padLeft(2, '0')}';
      }
      return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    });

    final sortedKeys = sections.keys.toList()..sort((a, b) => b.compareTo(a));

    return CustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: topPad + 60 + extraTop)),
        for (final key in sortedKeys) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _getLabel(key, _viewMode),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: photoGridDelegate,
            delegate: SliverChildBuilderDelegate((_, i) {
              final sectionPhotos = sections[key]!;
              return PhotoTile(
                photo: sectionPhotos[i],
                onTap: () => onTap(sectionPhotos, i),
                onLongPress: () {},
              );
            }, childCount: sections[key]!.length),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  void _openViewer(BuildContext context, List<PhotoItem> photos, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) => PhotoViewerScreen(
          photos: photos,
          initialIndex: index,
          routeAnimation: animation,
        ),
      ),
    );
  }
}
