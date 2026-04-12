import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

class DistrictsGrid extends StatelessWidget {
  const DistrictsGrid({
    super.key,
    required this.byDistrict,
    required this.provinceName,
    required this.onSelectDistrict,
  });

  final Map<String, List<PhotoItem>> byDistrict;
  final String provinceName;
  final ValueChanged<String> onSelectDistrict;

  @override
  Widget build(BuildContext context) {
    final districts = byDistrict.keys.where((d) => d != 'Unknown').toList()
      ..sort();

    if (districts.isEmpty) {
      return const Center(child: Text('No photos categorized by district'));
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 80,
        16,
        16,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: districts.length,
      itemBuilder: (context, index) {
        final district = districts[index];
        final photos = byDistrict[district]!;
        final newestPhoto = photos.reduce(
          (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
        );

        return GestureDetector(
          onTap: () => onSelectDistrict(district),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (newestPhoto.assetEntity != null)
                  DistrictThumbnail(entity: newestPhoto.assetEntity!),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        district,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${photos.length} photos',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DistrictThumbnail extends StatelessWidget {
  const DistrictThumbnail({super.key, required this.entity});
  final AssetEntity entity;

  @override
  Widget build(BuildContext context) {
    return AssetEntityImage(
      entity,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize(400, 400),
      fit: BoxFit.cover,
    );
  }
}
