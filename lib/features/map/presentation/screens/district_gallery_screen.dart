import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photo_tile.dart';
import 'package:photo_map/features/gallery/presentation/widgets/viewer/photo_viewer_screen.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photos_tab.dart';
import 'package:photo_map/features/map/presentation/widgets/province_district/province_header.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/common_widgets/view_mode_sheet.dart';

class DistrictGalleryScreen extends ConsumerStatefulWidget {
  final String provinceName;
  final String districtName;
  final List<PhotoItem> photos;

  const DistrictGalleryScreen({
    super.key,
    required this.provinceName,
    required this.districtName,
    required this.photos,
  });

  @override
  ConsumerState<DistrictGalleryScreen> createState() =>
      _DistrictGalleryScreenState();
}

class _DistrictGalleryScreenState extends ConsumerState<DistrictGalleryScreen> {
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
    final topPad = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

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
            child: Positioned.fill(child: _buildGrid(context, topPad, theme)),
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
                    title: '${widget.districtName}, ${widget.provinceName}',
                    viewMode: ProvinceViewMode.grid,
                    isSelectingDistrict: true,
                    onBack: () => Navigator.pop(context),
                    onToggleMode: () {},
                  ),
                ),
                const SizedBox(width: 8),
                GlassCard(
                  borderRadius: 12,
                  padding: const EdgeInsets.all(8),
                  onTap: _showFilterSheet,
                  child: const Icon(Icons.filter_list_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, double topPad, ThemeData theme) {
    if (_viewMode == ViewMode.all) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(1.5, topPad + 88, 1.5, 32),
        gridDelegate: photoGridDelegate,
        itemCount: widget.photos.length,
        itemBuilder: (_, i) => PhotoTile(
          photo: widget.photos[i],
          onTap: () => _openViewer(context, widget.photos, i),
          onLongPress: () {},
        ),
      );
    }

    final sections = _groupBy(widget.photos, (p) {
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
        SliverPadding(padding: EdgeInsets.only(top: topPad + 60)),
        for (final key in sortedKeys) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _getLabel(key, _viewMode),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
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
                onTap: () => _openViewer(context, sectionPhotos, i),
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
