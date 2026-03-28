import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/province/data/province_data.dart';
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

class AlbumsTab extends ConsumerWidget {
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
  final void Function(PhotoItem, String) onTap;
  final void Function(PhotoItem) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (inProvince) return _provincePhotos(ref);
    if (inCountry) return _provincesGrid(ref);
    return _countriesGrid(ref);
  }

  Widget _countriesGrid(WidgetRef ref) {
    final byCountry = gallery.photosByCountry;
    if (byCountry.isEmpty) {
      return EmptyView(
        message:
            gallery.isGeocoding ? 'Detecting locations...' : 'No photos found',
        sub: gallery.isGeocoding ? 'Your photos will appear shortly' : '',
        showSpinner: gallery.isGeocoding,
      );
    }
    final names = byCountry.keys.toList()..sort();
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(10, contentTopPad, 10, 10),
      gridDelegate: _albumGridDelegate,
      itemCount: names.length,
      itemBuilder: (_, i) {
        final name = names[i];
        final flag = countries.where((c) => c.name == name).firstOrNull?.flag;
        return AlbumCard(
          title: name,
          subtitle: '${byCountry[name]!.length} photos',
          leading: flag,
          coverPhoto: byCountry[name]!.first,
          onTap: () =>
              ref.read(galleryStateProvider.notifier).selectCountry(name),
        );
      },
    );
  }

  Widget _provincesGrid(WidgetRef ref) {
    final byProvince = gallery.photosByProvince(gallery.selectedCountry);
    if (byProvince.isEmpty) {
      return EmptyView(
          message: 'No photos in ${gallery.selectedCountry}', sub: '');
    }
    final names = byProvince.keys.toList()..sort();
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(10, contentTopPad, 10, 10),
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

  Widget _provincePhotos(WidgetRef ref) {
    final photos = gallery.filteredPhotos;
    if (photos.isEmpty) {
      return const EmptyView(
          message: 'No photos here',
          sub: 'Tap the button below to add photos');
    }
    return GridView.builder(
      padding: EdgeInsets.only(top: contentTopPad),
      gridDelegate: photoGridDelegate,
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final photo = photos[i];
        final tag =
            'album_${gallery.selectedCountry}_${gallery.selectedProvince}_$i';
        return PhotoTile(
          photo: photo,
          heroTag: tag,
          onTap: () => onTap(photo, tag),
          onLongPress: () => onLongPress(photo),
        );
      },
    );
  }
}
