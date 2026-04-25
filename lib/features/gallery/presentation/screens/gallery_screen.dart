import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/gallery_notifier.dart';
import '../providers/gallery_select_provider.dart';
import '../widgets/main_gallery/albums_tab.dart';
import '../widgets/main_gallery/gallery_header.dart';
import '../widgets/viewer/photo_options_sheet.dart';
import '../widgets/viewer/photo_viewer_screen.dart';
import '../widgets/main_gallery/photos_tab.dart';
import 'package:photo_map/common_widgets/view_mode_sheet.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;
  ViewMode _viewMode = ViewMode.all;
  double _contentTopPad = 0;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _isScrolled = false));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(galleryStateProvider.notifier).silentReload();
    }
  }

  bool get _inAlbumsTab => _tabs.index == 1;

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryStateProvider);
    final select = ref.watch(gallerySelectProvider);
    final theme = Theme.of(context);
    final inCountry = gallery.selectedCountry != 'All';
    final inProvince = inCountry && gallery.selectedProvince != 'All';
    final topPad = MediaQuery.paddingOf(context).top;
    _contentTopPad = topPad + 88;

    final sortedPhotos = [...gallery.allPhotos]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              final scrolled = n.metrics.pixels > 0;
              if (scrolled != _isScrolled)
                setState(() => _isScrolled = scrolled);
              return false;
            },
            child: _buildBody(
              context,
              gallery,
              theme,
              inCountry,
              inProvince,
              sortedPhotos,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _contentTopPad + 28,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isScrolled ? 0.6 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.surface,
                        theme.colorScheme.surface,
                        theme.colorScheme.surface.withOpacity(0),
                      ],
                      stops: const [0.0, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: () {
              final currentViewPhotos = (_inAlbumsTab && inProvince)
                  ? ([...gallery.filteredPhotos]
                    ..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
                  : sortedPhotos;

              return GalleryHeader(
                topPad: topPad,
                inAlbumsTab: _inAlbumsTab,
                inCountry: inCountry,
                inProvince: inProvince,
                selectedCountry: gallery.selectedCountry,
                selectedProvince: gallery.selectedProvince,
                onPhotoTab: () => _tabs.animateTo(0),
                onAlbumTab: () => _tabs.animateTo(1),
                onBack: () {
                  final notifier = ref.read(galleryStateProvider.notifier);
                  inProvince
                      ? notifier.selectProvince('All')
                      : notifier.selectCountry('All');
                },
                onFilterTap: () => _showFilterSheet(context, theme),
                isSelectMode: select.isSelectMode,
                selectedCount: select.selectedCount,
                totalCount: currentViewPhotos.length,
                onEnterSelect: () =>
                    ref.read(gallerySelectProvider.notifier).enter(),
                onCancelSelect: () =>
                    ref.read(gallerySelectProvider.notifier).exit(),
                onSelectAll: () {
                  final notifier = ref.read(gallerySelectProvider.notifier);
                  if (select.selectedCount == currentViewPhotos.length) {
                    notifier.clearSelection();
                  } else {
                    notifier.selectAll(currentViewPhotos.map((p) => p.path));
                  }
                },
              );
            }(),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    GalleryState gallery,
    ThemeData theme,
    bool inCountry,
    bool inProvince,
    List<PhotoItem> sortedPhotos,
  ) {
    if (gallery.isLoading) {
      return GridView.builder(
        padding: EdgeInsets.only(top: _contentTopPad, left: 2, right: 2, bottom: 120),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 18,
        itemBuilder: (_, __) => const ShimmerPlaceholder(),
      );
    }

    if (gallery.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: theme.colorScheme.error.withAlpha(128),
              ),
              const Gap(16),
              Text(
                'Error',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const Gap(8),
              Text(
                gallery.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final select = ref.watch(gallerySelectProvider);
    return TabBarView(
      controller: _tabs,
      physics: inCountry
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      children: [
        PhotosTab(
          photos: sortedPhotos,
          viewMode: _viewMode,
          contentTopPad: _contentTopPad,
          isEmpty: gallery.allPhotos.isEmpty && !gallery.isGeocoding,
          isSelectMode: select.isSelectMode,
          selectedPaths: select.selectedPaths,
          onToggleSelect: (photo) =>
              ref.read(gallerySelectProvider.notifier).toggle(photo.path),
          onTap: (photos, index) => _openViewer(context, photos, index),
          onLongPress: (photo) => _showPhotoOptions(context, photo),
        ),
        AlbumsTab(
          gallery: gallery,
          contentTopPad: _contentTopPad,
          inCountry: inCountry,
          inProvince: inProvince,
          viewMode: _viewMode,
          isSelectMode: select.isSelectMode,
          selectedPaths: select.selectedPaths,
          onToggleSelect: (photo) =>
              ref.read(gallerySelectProvider.notifier).toggle(photo.path),
          onTap: (photos, index) => _openViewer(context, photos, index),
          onLongPress: (photo) => _showPhotoOptions(context, photo),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context, ThemeData theme) {
    showViewModeSheet(
      context,
      current: _viewMode,
      onSelected: (v) => setState(() => _viewMode = v),
    );
  }

  // ignore: unused_element
  Future<void> _pickImage(String province) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      ref.read(galleryStateProvider.notifier).addPhoto(image.path, province);
    }
  }

  void _openViewer(
    BuildContext context,
    List<PhotoItem> photos,
    int initialIndex,
  ) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) => PhotoViewerScreen(
          photos: photos,
          initialIndex: initialIndex,
          routeAnimation: animation,
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, PhotoItem photo) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => PhotoOptionsSheet(
        photo: photo,
        onDelete: () {
          Navigator.pop(ctx);
          showDialog<void>(
            context: context,
            builder: (dlg) => AlertDialog(
              title: const Text('Delete Photo'),
              content: const Text(
                'Are you sure you want to delete this photo?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlg),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    Navigator.pop(dlg);
                    ref
                        .read(galleryStateProvider.notifier)
                        .removePhoto(photo.path);
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withAlpha(15) : Colors.grey[200]!,
      highlightColor: isDark ? Colors.white.withAlpha(30) : Colors.grey[50]!,
      child: Container(
        color: Colors.white,
      ),
    );
  }
}
