import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/presentation/providers/cover_photo_provider.dart';
import 'package:photo_map/features/map/presentation/screens/cover_crop_screen.dart';
import 'package:photo_map/features/map/presentation/screens/province_district_screen.dart';
import 'package:photo_map/features/map/presentation/screens/province_gallery_screen.dart';

class ProvinceMenuSheet extends ConsumerWidget {
  const ProvinceMenuSheet({super.key, required this.provinceName});

  final String provinceName;

  String get _normalized =>
      provinceName.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSheetHandle(title: provinceName),
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('View by Districts'),
          subtitle: const Text('Browse photos by district'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProvinceDistrictScreen(provinceName: provinceName),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('View Gallery'),
          subtitle: const Text('All photos in this province'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProvinceGalleryScreen(provinceName: provinceName),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('Change Cover Photo'),
          subtitle: const Text('Pick which photo appears on the map'),
          onTap: () {
            // Capture both nav and notifier BEFORE popping — the sheet's
            // context and ref become invalid after it is dismissed.
            final nav = Navigator.of(context, rootNavigator: true);
            final notifier = ref.read(coverPhotoProvider.notifier);
            Navigator.pop(context);
            _openPickCover(nav, notifier);
          },
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }

  Future<void> _openPickCover(NavigatorState nav, CoverPhotoNotifier notifier) async {
    // Step 1: Open gallery in pick mode — pops with the selected PhotoItem
    final photo = await nav.push<PhotoItem>(
      MaterialPageRoute<PhotoItem>(
        builder: (ctx) => ProvinceGalleryScreen(
          provinceName: provinceName,
          onPickCover: (p) => Navigator.of(ctx).pop(p),
        ),
      ),
    );
    if (photo == null) return;

    // Step 2: Open crop screen — pops with the normalized crop Rect
    final cropRect = await nav.push<Rect>(
      MaterialPageRoute<Rect>(
        builder: (_) =>
            CoverCropScreen(photo: photo, provinceName: provinceName),
      ),
    );
    if (cropRect == null) return;

    // Step 3: Save cover
    final assetId = photo.assetEntity?.id ?? photo.path;
    await notifier.setCover(_normalized, assetId, cropRect);
  }
}
