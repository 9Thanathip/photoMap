import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_button.dart';
import 'package:photo_map/features/map/presentation/providers/province_map_provider.dart';
import 'package:photo_map/features/map/presentation/widgets/province_map_painter.dart';

class DistrictsMap extends ConsumerWidget {
  const DistrictsMap({
    super.key,
    required this.provinceName,
    required this.transformController,
    required this.onSelectDistrict,
    required this.baseColor,
    required this.canvasColor,
    required this.strokeColor,
    required this.currentTime,
    required this.openTime,
  });

  final String provinceName;
  final TransformationController transformController;
  final ValueChanged<String> onSelectDistrict;
  final Color baseColor;
  final Color canvasColor;
  final Color strokeColor;
  final DateTime currentTime;
  final DateTime openTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provinceMapProvider(provinceName));

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            AppButton(
              label: 'Retry',
              onPressed: () => ref
                  .read(provinceMapProvider(provinceName).notifier)
                  .loadMap(),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      transformationController: transformController,
      boundaryMargin: const EdgeInsets.all(120),
      minScale: 0.4,
      maxScale: 10.0,
      child: Center(
        child: GestureDetector(
          onTapUp: (details) {
            if (state.districts.isEmpty) return;
            
            Rect totalBounds = state.districts.first.bounds;
            for (var d in state.districts.skip(1)) {
              totalBounds = totalBounds.expandToInclude(d.bounds);
            }

            const canvasSize = Size(1000, 1000);
            final scaleX = canvasSize.width / totalBounds.width;
            final scaleY = canvasSize.height / totalBounds.height;
            final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;

            final offsetX =
                (canvasSize.width - totalBounds.width * scale) / 2 -
                totalBounds.left * scale;
            final offsetY =
                (canvasSize.height - totalBounds.height * scale) / 2 -
                totalBounds.top * scale;

            final px = (details.localPosition.dx - offsetX) / scale;
            final py = (details.localPosition.dy - offsetY) / scale;
            final mapPoint = Offset(px, py);

            for (var district in state.districts) {
              if (district.path.contains(mapPoint)) {
                onSelectDistrict(district.name);
                break;
              }
            }
          },
          child: CustomPaint(
            size: const Size(1000, 1000),
            painter: ProvinceMapPainter(
              districts: state.districts,
              combinedPath: state.combinedPath,
              districtPhotos: state.districtPhotos,
              imageLoadTimes: state.imageLoadTimes,
              currentTime: currentTime,
              openTime: openTime,
              baseColor: baseColor,
              canvasColor: canvasColor,
              strokeColor: strokeColor,
            ),
          ),
        ),
      ),
    );
  }
}
