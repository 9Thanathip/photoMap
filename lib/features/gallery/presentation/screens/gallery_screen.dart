import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import '../providers/gallery_notifier.dart';
import '../providers/gallery_select_provider.dart';
import '../widgets/albums_tab.dart';
import '../widgets/gallery_header.dart';
import '../widgets/location_selector_sheet.dart';
import '../widgets/photo_options_sheet.dart';
import '../widgets/photo_viewer_screen.dart';
import '../widgets/photos_tab.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';

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
            child: GalleryHeader(
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
              totalCount: sortedPhotos.length,
              onEnterSelect: !_inAlbumsTab
                  ? () => ref.read(gallerySelectProvider.notifier).enter()
                  : null,
              onCancelSelect: () =>
                  ref.read(gallerySelectProvider.notifier).exit(),
              onSelectAll: () {
                final notifier = ref.read(gallerySelectProvider.notifier);
                if (select.selectedCount == sortedPhotos.length) {
                  notifier.clearSelection();
                } else {
                  notifier.selectAll(sortedPhotos.map((p) => p.path));
                }
              },
            ),
          ),

          // Custom Glassmorphic 'Add Photo' Button
          if (!select.isSelectMode && (_inAlbumsTab && inProvince))
            Positioned(
              right: 28,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
              child: GlassCard(
                onTap: () => _pickImage(gallery.selectedProvince),
                borderRadius: 100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
            const Gap(16),
            Text(
              'Loading photos...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
          onTap: (photos, index) => _openViewer(context, photos, index),
          onLongPress: (photo) => _showPhotoOptions(context, photo),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context, ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHandle(title: 'View Mode'),
          ...ViewMode.values.map(
            (m) => ListTile(
              title: Text(m.label, style: GoogleFonts.poppins(fontSize: 14)),
              trailing: _viewMode == m
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                setState(() => _viewMode = m);
                Navigator.pop(context);
              },
            ),
          ),
          const Gap(16),
        ],
      ),
    );
  }

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
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: PhotoViewerScreen(
              photos: photos,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, PhotoItem photo) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => PhotoOptionsSheet(
        photo: photo,
        onAddToAlbums: () {
          Navigator.pop(ctx);
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => LocationSelectorSheet(photo: photo),
          );
        },
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
