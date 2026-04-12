import 'package:flutter/material.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/features/map/presentation/screens/province_district_screen.dart';
import 'package:photo_map/features/map/presentation/screens/province_gallery_screen.dart';

class ProvinceMenuSheet extends StatelessWidget {
  const ProvinceMenuSheet({
    super.key,
    required this.provinceName,
  });

  final String provinceName;

  @override
  Widget build(BuildContext context) {
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
                builder: (_) => ProvinceDistrictScreen(provinceName: provinceName),
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
                builder: (_) => ProvinceGalleryScreen(provinceName: provinceName),
              ),
            );
          },
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }
}
