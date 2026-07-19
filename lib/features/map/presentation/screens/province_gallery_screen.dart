import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_empty_state.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../../gallery/presentation/providers/gallery_notifier.dart';
import '../../../gallery/presentation/widgets/main_gallery/photo_tile.dart';
import '../../../gallery/presentation/widgets/viewer/photo_viewer_screen.dart';
import '../../../gallery/presentation/widgets/main_gallery/photos_tab.dart';
import '../widgets/province_district/province_header.dart';
import 'package:photo_map/common_widgets/view_mode_sheet.dart';
import '../providers/province_map_provider.dart';

class ProvinceGalleryScreen extends ConsumerStatefulWidget {
  const ProvinceGalleryScreen({
    super.key,
    required this.countryId,
    required this.provinceName,
    this.districtName,
    this.onPickCover,
  });

  final String countryId;
  final String provinceName;
  final String? districtName;

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

  String _getLabel(String k, ViewMode mode, List<String> months) {
    if (mode == ViewMode.year) return k;
    if (mode == ViewMode.month) {
      final parts = k.split('-');
      return '${months[int.parse(parts[1]) - 1]} ${parts[0]}';
    }
    if (mode == ViewMode.day) {
      final parts = k.split('-');
      return '${int.parse(parts[2])} ${months[int.parse(parts[1]) - 1]} ${parts[0]}';
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
    final mapState = ref.watch(provinceMapProvider(
      ProvinceMapParams(
        countryId: widget.countryId,
        provinceName: widget.provinceName,
      ),
    ));

    final photos = widget.districtName != null
        ? (mapState.allPhotosByDistrict[widget.districtName] ?? [])
        : gallery.allPhotos
              .where((p) => p.province == widget.provinceName)
              .toList();

    photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final topPad = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

    final isPickMode = widget.onPickCover != null;

    return Scaffold(
      backgroundColor: context.tokens.surfaceBase,
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
              child: (mapState.isLoading || (gallery.isLoading && photos.isEmpty))
                  ? const Center(child: CircularProgressIndicator())
                  : (photos.isEmpty && !gallery.isGeocoding)
                      ? AppEmptyState(
                          icon: AppIcons.photo_library_outlined,
                          title: AppLocalizations.of(context).noPhotosIn(
                              widget.districtName ?? widget.provinceName),
                          subtitle: AppLocalizations.of(context)
                              .provinceGallerySubtitle,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.92,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.touch_app_outlined,
                      size: 16,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).coverTapHint,
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

          // Top gradient protection (always-on, deepens on scroll).
          // Light theme → black scrim (matches map_screen).
          // Dark theme → surface-tinted scrim that solidifies on scroll.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 110,
            child: IgnorePointer(
              child: context.isDark
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  context.tokens.surfaceBase.withValues(alpha: 0.85),
                                  context.tokens.surfaceBase.withValues(alpha: 0.55),
                                  context.tokens.surfaceBase.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _isScrolled ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    context.tokens.surfaceBase,
                                    context.tokens.surfaceBase,
                                    context.tokens.surfaceBase.withAlpha(0),
                                  ],
                                  stops: const [0.0, 0.72, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(
                              alpha: _isScrolled ? 0.55 : 0.32,
                            ),
                            Colors.black.withValues(
                              alpha: _isScrolled ? 0.25 : 0.12,
                            ),
                            Colors.black.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
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
                    title: widget.districtName ?? widget.provinceName,
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
                      AppIcons.filter_list_rounded,
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
        SliverPadding(padding: EdgeInsets.only(top: topPad + 60 + extraTop)),
        for (final key in sortedKeys) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _getLabel(key, _viewMode,
                    AppLocalizations.of(context).monthsShort),
                style: TextStyle(
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
              final globalIndex = offsets[key]! + i;
              return PhotoTile(
                photo: sectionPhotos[i],
                onTap: () => onTap(flat, globalIndex),
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
