import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../gallery/presentation/providers/gallery_notifier.dart';
import '../../../gallery/presentation/widgets/album_card.dart';
import '../../../gallery/presentation/widgets/photo_tile.dart';
import '../../../gallery/presentation/widgets/photo_viewer_screen.dart';
import '../../../gallery/presentation/widgets/photos_tab.dart' show photoGridDelegate;

const _albumGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
  childAspectRatio: 0.92,
);

class ProvinceDistrictScreen extends ConsumerStatefulWidget {
  const ProvinceDistrictScreen({super.key, required this.provinceName});

  final String provinceName;

  @override
  ConsumerState<ProvinceDistrictScreen> createState() =>
      _ProvinceDistrictScreenState();
}

class _ProvinceDistrictScreenState
    extends ConsumerState<ProvinceDistrictScreen> {
  String? _selectedDistrict;
  bool _goingDeeper = true;

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryStateProvider);
    final byDistrict = gallery.photosByDistrict(widget.provinceName);

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _selectedDistrict ?? widget.provinceName,
            key: ValueKey(_selectedDistrict ?? widget.provinceName),
          ),
        ),
        centerTitle: true,
        leading: _selectedDistrict != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() {
                  _goingDeeper = false;
                  _selectedDistrict = null;
                }),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = _selectedDistrict != null
              ? (child.key == ValueKey(_selectedDistrict))
              : (child.key == const ValueKey('districts'));
          final slideBegin = _goingDeeper
              ? (isIncoming
                  ? const Offset(0.08, 0)
                  : const Offset(-0.08, 0))
              : (isIncoming
                  ? const Offset(-0.08, 0)
                  : const Offset(0.08, 0));
          return SlideTransition(
            position:
                Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: _selectedDistrict != null
            ? _DistrictPhotosGrid(
                key: ValueKey(_selectedDistrict),
                photos: byDistrict[_selectedDistrict] ?? [],
                districtName: _selectedDistrict!,
              )
            : _DistrictsGrid(
                key: const ValueKey('districts'),
                byDistrict: byDistrict,
                provinceName: widget.provinceName,
                onSelectDistrict: (d) => setState(() {
                  _goingDeeper = true;
                  _selectedDistrict = d;
                }),
              ),
      ),
    );
  }
}

// ── Districts album grid ──────────────────────────────────────────────────────

class _DistrictsGrid extends StatelessWidget {
  const _DistrictsGrid({
    super.key,
    required this.byDistrict,
    required this.provinceName,
    required this.onSelectDistrict,
  });

  final Map<String, List<PhotoItem>> byDistrict;
  final String provinceName;
  final void Function(String) onSelectDistrict;

  @override
  Widget build(BuildContext context) {
    if (byDistrict.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined,
                size: 64,
                color:
                    Theme.of(context).colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 12),
            Text('No photos in $provinceName',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final names = byDistrict.keys.where((k) => k != 'Unknown').toList()
      ..sort();
    final unknownPhotos = byDistrict['Unknown'];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      gridDelegate: _albumGridDelegate,
      itemCount: names.length + (unknownPhotos != null ? 1 : 0),
      itemBuilder: (_, i) {
        final name = i < names.length ? names[i] : 'Unknown';
        final photos = byDistrict[name]!;
        return AlbumCard(
          title: name,
          subtitle: '${photos.length} photos',
          coverPhoto: photos.first,
          onTap: () => onSelectDistrict(name),
        );
      },
    );
  }
}

// ── District photo grid ───────────────────────────────────────────────────────

class _DistrictPhotosGrid extends StatelessWidget {
  const _DistrictPhotosGrid({
    super.key,
    required this.photos,
    required this.districtName,
  });

  final List<PhotoItem> photos;
  final String districtName;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Center(
        child: Text('No photos in $districtName',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    final sorted = [...photos]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return GridView.builder(
      padding: const EdgeInsets.all(1.5),
      gridDelegate: photoGridDelegate,
      itemCount: sorted.length,
      itemBuilder: (_, i) => PhotoTile(
        photo: sorted[i],
        onTap: () => _openViewer(context, sorted, i),
        onLongPress: () {},
      ),
    );
  }

  void _openViewer(
      BuildContext context, List<PhotoItem> photos, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: PhotoViewerScreen(photos: photos, initialIndex: index),
        ),
      ),
    );
  }
}
