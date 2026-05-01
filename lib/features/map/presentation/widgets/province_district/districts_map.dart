import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_button.dart';
import 'package:photo_map/features/map/presentation/providers/province_map_provider.dart';
import 'package:photo_map/features/map/presentation/widgets/province_map_painter.dart';

class DistrictsMap extends ConsumerStatefulWidget {
  const DistrictsMap({
    super.key,
    required this.countryId,
    required this.provinceName,
    required this.transformController,
    required this.onSelectDistrict,
    required this.baseColor,
    required this.canvasColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.currentTime,
    required this.openTime,
  });

  final String countryId;
  final String provinceName;
  final TransformationController transformController;
  final ValueChanged<String> onSelectDistrict;
  final Color baseColor;
  final Color canvasColor;
  final Color strokeColor;
  final double strokeWidth;
  final DateTime currentTime;
  final DateTime openTime;

  @override
  ConsumerState<DistrictsMap> createState() => _DistrictsMapState();
}

class _DistrictsMapState extends ConsumerState<DistrictsMap> {
  final GlobalKey _paintKey = GlobalKey();
  Offset? _tapDownPosition;

  final Map<String, DateTime> _firstSeenTimes = {};
  static const int _staggerMs = 80;

  void _handleTap(Offset globalPosition, List<DistrictShape> districts) {
    if (districts.isEmpty) return;

    final renderBox =
        _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Convert global screen position → CustomPaint local space
    final canvasPos = renderBox.globalToLocal(globalPosition);
    final canvasSize = renderBox.size;

    // Replicate painter's coordinate transform
    Rect totalBounds = districts.first.bounds;
    for (final d in districts.skip(1)) {
      totalBounds = totalBounds.expandToInclude(d.bounds);
    }
    final scaleX = canvasSize.width / totalBounds.width;
    final scaleY = canvasSize.height / totalBounds.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;
    final offsetX =
        (canvasSize.width - totalBounds.width * scale) / 2 -
        totalBounds.left * scale;
    final offsetY =
        (canvasSize.height - totalBounds.height * scale) / 2 -
        totalBounds.top * scale;

    // Convert canvas position → district coordinate space
    final px = (canvasPos.dx - offsetX) / scale;
    final py = (canvasPos.dy - offsetY) / scale;
    final mapPoint = Offset(px, py);

    for (final district in districts) {
      if (district.path.contains(mapPoint)) {
        widget.onSelectDistrict(district.name);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provinceMapProvider(
      ProvinceMapParams(
        countryId: widget.countryId,
        provinceName: widget.provinceName,
      ),
    ));

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
                  .read(provinceMapProvider(
                    ProvinceMapParams(
                      countryId: widget.countryId,
                      provinceName: widget.provinceName,
                    ),
                  ).notifier)
                  .loadMap(),
            ),
          ],
        ),
      );
    }

    // Register first-seen time at the exact frame each district image appears.
    final newKeys = state.districtPhotos.keys
        .where((k) => state.districtPhotos[k] != null && !_firstSeenTimes.containsKey(k))
        .toList()
      ..sort();
    if (newKeys.isNotEmpty) {
      final now = DateTime.now();
      for (var i = 0; i < newKeys.length; i++) {
        _firstSeenTimes[newKeys[i]] = now.add(Duration(milliseconds: i * _staggerMs));
      }
    }

    return Listener(
      onPointerDown: (e) => _tapDownPosition = e.position,
      onPointerUp: (e) {
        final down = _tapDownPosition;
        _tapDownPosition = null;
        if (down != null && (e.position - down).distance < 18) {
          _handleTap(e.position, state.districts);
        }
      },
      child: InteractiveViewer(
        transformationController: widget.transformController,
        boundaryMargin: const EdgeInsets.all(120),
        minScale: 0.4,
        maxScale: 10.0,
        child: Center(
          child: CustomPaint(
            key: _paintKey,
            size: const Size(1000, 1000),
            painter: ProvinceMapPainter(
              districts: state.districts,
              combinedPath: state.combinedPath,
              districtPhotos: state.districtPhotos,
              imageLoadTimes: _firstSeenTimes,
              currentTime: widget.currentTime,
              openTime: widget.openTime,
              baseColor: widget.baseColor,
              canvasColor: widget.canvasColor,
              strokeColor: widget.strokeColor,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}
