import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gallery_notifier.dart';
import 'album_card.dart';
import 'empty_view.dart';
import 'photo_tile.dart';
import 'photos_tab.dart' show photoGridDelegate;

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
  });

  final GalleryState gallery;
  final double contentTopPad;
  final bool inCountry;
  final bool inProvince;
  final void Function(List<PhotoItem> photos, int index) onTap;
  final void Function(PhotoItem) onLongPress;

  @override
  ConsumerState<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends ConsumerState<AlbumsTab> {
  bool _goingDeeper = true;

  int _depthOf(bool inCountry, bool inProvince) =>
      inProvince ? 2 : (inCountry ? 1 : 0);

  @override
  void didUpdateWidget(AlbumsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldD = _depthOf(oldWidget.inCountry, oldWidget.inProvince);
    final newD = _depthOf(widget.inCountry, widget.inProvince);
    if (newD != oldD) _goingDeeper = newD > oldD;
  }

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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        // Incoming child has the current switchKey; outgoing has the previous one.
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
          position: Tween<Offset>(begin: slideBegin, end: Offset.zero)
              .animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(switchKey), child: content),
    );
  }

  Widget _countriesGrid() {
    final byCountry = widget.gallery.photosByCountry;
    if (byCountry.isEmpty) {
      return EmptyView(
        message: widget.gallery.isGeocoding
            ? 'Detecting locations...'
            : 'No photos found',
        sub: widget.gallery.isGeocoding ? 'Your photos will appear shortly' : '',
        showSpinner: widget.gallery.isGeocoding,
      );
    }
    final names = byCountry.keys.where((k) => k != 'Unknown').toList()..sort();
    return GridView.builder(
      padding:
          EdgeInsets.fromLTRB(10, widget.contentTopPad, 10, 10),
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
      return EmptyView(
          message: 'No photos in ${widget.gallery.selectedCountry}', sub: '');
    }
    final names = byProvince.keys.toList()..sort();
    return GridView.builder(
      padding:
          EdgeInsets.fromLTRB(10, widget.contentTopPad, 10, 10),
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

  Widget _provincePhotos() {
    final photos = widget.gallery.filteredPhotos;
    if (photos.isEmpty) {
      return const EmptyView(
          message: 'No photos here',
          sub: 'Tap the button below to add photos');
    }
    return GridView.builder(
      padding: EdgeInsets.only(top: widget.contentTopPad),
      gridDelegate: photoGridDelegate,
      itemCount: photos.length,
      itemBuilder: (_, i) => PhotoTile(
        photo: photos[i],
        onTap: () => widget.onTap(photos, i),
        onLongPress: () => widget.onLongPress(photos[i]),
      ),
    );
  }
}
