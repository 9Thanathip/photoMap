import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/presentation/providers/cover_photo_provider.dart';
import 'package:photo_map/features/map/presentation/screens/cover_crop_screen.dart';
import 'package:photo_map/features/map/presentation/screens/province_district_screen.dart';
import 'package:photo_map/features/map/presentation/screens/province_gallery_screen.dart';
import 'package:photo_map/l10n/app_localizations.dart';

class ProvinceMenuSheet extends ConsumerWidget {
  const ProvinceMenuSheet({
    super.key,
    required this.countryId,
    required this.provinceName,
  });

  final String countryId;
  final String provinceName;

  String get _normalized =>
      provinceName.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final botPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: botPad),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHandle(title: provinceName),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withAlpha(80),
          ),
        ListTile(
          leading: const Icon(AppIcons.map_outlined),
          title: Text(l10n.menuViewDistricts),
          subtitle: Text(l10n.menuViewDistrictsSub),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => ProvinceDistrictScreen(
                  countryId: countryId,
                  provinceName: provinceName,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(AppIcons.photo_library_outlined),
          title: Text(l10n.menuViewGallery),
          subtitle: Text(l10n.menuViewGallerySub),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => ProvinceGalleryScreen(
                  countryId: countryId,
                  provinceName: provinceName,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(AppIcons.image_outlined),
          title: Text(l10n.menuChangeCover),
          subtitle: Text(l10n.menuChangeCoverSub),
          onTap: () {
            // Capture both nav and notifier BEFORE popping — the sheet's
            // context and ref become invalid after it is dismissed.
            final nav = Navigator.of(context, rootNavigator: true);
            final notifier = ref.read(coverPhotoProvider.notifier);
            Navigator.pop(context);
            _openPickCover(nav, notifier);
          },
        ),
      ],
    ),
    );
  }

  Future<void> _openPickCover(NavigatorState nav, CoverPhotoNotifier notifier) async {
    // Step 1: Open gallery in pick mode — pops with the selected PhotoItem
    final photo = await nav.push<PhotoItem>(
      MaterialPageRoute<PhotoItem>(
        builder: (ctx) => ProvinceGalleryScreen(
          countryId: countryId,
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
