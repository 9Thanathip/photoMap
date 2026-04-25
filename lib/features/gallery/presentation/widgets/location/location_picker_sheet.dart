import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../providers/gallery_notifier.dart';

class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key, required this.photo});

  final PhotoItem photo;

  @override
  ConsumerState<LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  String? _country;
  bool _goingDeeper = true;

  void _selectCountry(String country) =>
      setState(() { _goingDeeper = true; _country = country; });

  void _goBack() =>
      setState(() { _goingDeeper = false; _country = null; });

  void _selectProvince(BuildContext context, String country, String province) {
    ref
        .read(galleryStateProvider.notifier)
        .updatePhotoLocation(widget.photo.path, country, province);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location set to $province'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryStateProvider);
    final theme = Theme.of(context);
    final isInCountry = _country != null;
    final title = isInCountry ? _country! : 'Set Location';

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (sheetContext, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      title,
                      key: ValueKey(title),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isInCountry)
                    Positioned(
                      left: 4,
                      child: IconButton(
                        icon: const Icon(
                            Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: _goBack,
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withAlpha(80),
            ),
            // Grid
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final isIncoming = (child.key as ValueKey?)?.value ==
                      (_country ?? 'countries');
                  final slideBegin = _goingDeeper
                      ? (isIncoming
                          ? const Offset(0.08, 0)
                          : const Offset(-0.08, 0))
                      : (isIncoming
                          ? const Offset(-0.08, 0)
                          : const Offset(0.08, 0));
                  return SlideTransition(
                    position: Tween<Offset>(
                            begin: slideBegin, end: Offset.zero)
                        .animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: isInCountry
                    ? _ProvincesGrid(
                        key: ValueKey(_country),
                        gallery: gallery,
                        country: _country!,
                        scrollController: scrollController,
                        onSelect: (province) =>
                            _selectProvince(context, _country!, province),
                      )
                    : _CountriesGrid(
                        key: const ValueKey('countries'),
                        gallery: gallery,
                        scrollController: scrollController,
                        onSelect: _selectCountry,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Countries grid ────────────────────────────────────────────────────────────

class _CountriesGrid extends StatelessWidget {
  const _CountriesGrid({
    super.key,
    required this.gallery,
    required this.scrollController,
    required this.onSelect,
  });

  final GalleryState gallery;
  final ScrollController scrollController;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final byCountry = gallery.photosByCountry;
    final names = byCountry.keys.where((k) => k != 'Unknown').toList()..sort();

    if (names.isEmpty) {
      return const Center(child: Text('No albums found'));
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: _kAlbumGrid,
      itemCount: names.length,
      itemBuilder: (_, i) {
        final name = names[i];
        final photos = byCountry[name]!;
        return _AlbumCard(
          cover: photos.first,
          title: name,
          count: photos.length,
          onTap: () => onSelect(name),
        );
      },
    );
  }
}

// ── Provinces grid ────────────────────────────────────────────────────────────

class _ProvincesGrid extends StatelessWidget {
  const _ProvincesGrid({
    super.key,
    required this.gallery,
    required this.country,
    required this.scrollController,
    required this.onSelect,
  });

  final GalleryState gallery;
  final String country;
  final ScrollController scrollController;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final byProvince = gallery.photosByProvince(country);
    final names = byProvince.keys.toList()..sort();

    if (names.isEmpty) {
      return Center(child: Text('No albums in $country'));
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: _kAlbumGrid,
      itemCount: names.length,
      itemBuilder: (_, i) {
        final name = names[i];
        final photos = byProvince[name]!;
        return _AlbumCard(
          cover: photos.first,
          title: name,
          count: photos.length,
          onTap: () => onSelect(name),
        );
      },
    );
  }
}

// ── Album card ────────────────────────────────────────────────────────────────

class _AlbumCard extends StatefulWidget {
  const _AlbumCard({
    required this.cover,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final PhotoItem cover;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0,
      upperBound: 1,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = widget.cover.assetEntity;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: asset != null
                    ? Image(
                        image: AssetEntityImageProvider(
                          asset,
                          isOriginal: false,
                          thumbnailSize: const ThumbnailSize.square(300),
                        ),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        frameBuilder: (_, child, frame, sync) {
                          if (sync) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: child,
                          );
                        },
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.photo_library_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 36),
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(widget.title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('${widget.count} photos',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

const _kAlbumGrid = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
  childAspectRatio: 0.92,
);
