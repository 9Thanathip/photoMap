import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import '../providers/map_settings_provider.dart';
import '../providers/province_map_provider.dart';
import '../widgets/map_settings_widgets.dart';
import '../widgets/province_map_painter.dart';

enum _ViewMode { map, grid }

class ProvinceDistrictScreen extends ConsumerStatefulWidget {
  final String provinceName;
  const ProvinceDistrictScreen({super.key, required this.provinceName});

  @override
  ConsumerState<ProvinceDistrictScreen> createState() =>
      _ProvinceDistrictScreenState();
}

class _ProvinceDistrictScreenState
    extends ConsumerState<ProvinceDistrictScreen> with SingleTickerProviderStateMixin {
  _ViewMode _viewMode = _ViewMode.map;
  String? _selectedDistrict;
  bool _goingDeeper = false;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    // Use microtask to ensure provider is ready
    Future.microtask(() {
      ref.read(provinceMapProvider(widget.provinceName).notifier).loadMap();
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetView() {
    final Matrix4 end = Matrix4.identity();
    final Matrix4 start = _transformController.value;

    final animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final CurvedAnimation curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );

    curve.addListener(() {
      _transformController.value = Matrix4Tween(
        begin: start,
        end: end,
      ).evaluate(curve);
    });

    animation.forward().then((_) => animation.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryStateProvider);
    final byDistrict = gallery.photosByDistrict(widget.provinceName);
    final settings = ref.watch(mapSettingsProvider);
    final settingsNotifier = ref.read(mapSettingsProvider.notifier);

    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    final mapState = ref.watch(provinceMapProvider(widget.provinceName));

    final brightness = ThemeData.estimateBrightnessForColor(
      settings.provinceColor,
    );
    final strokeColor = brightness == Brightness.dark
        ? Colors.white30
        : Colors.white;

    void showSettings() {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SettingsSheet(
          currentProvince: settings.provinceColor,
          currentCanvas: settings.canvasColor,
          onProvinceSelect: settingsNotifier.updateProvinceColor,
          onCanvasSelect: settingsNotifier.updateCanvasColor,
        ),
      );
    }

    return Scaffold(
      backgroundColor: settings.canvasColor,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedDistrict != null
                ? Container(
                    color: Colors.white,
                    child: _DistrictPhotosGrid(
                      key: ValueKey(_selectedDistrict),
                      photos: List<PhotoItem>.from(
                        byDistrict[_selectedDistrict] ?? [],
                      )..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
                      districtName: _selectedDistrict!,
                    ),
                  )
                : (_viewMode == _ViewMode.map
                      ? _DistrictsMap(
                          provinceName: widget.provinceName,
                          transformController: _transformController,
                          baseColor: settings.provinceColor,
                          canvasColor: settings.canvasColor,
                          strokeColor: strokeColor,
                          onSelectDistrict: (d) => setState(() {
                            _goingDeeper = true;
                            _selectedDistrict = d;
                          }),
                        )
                      : _DistrictsGrid(
                          key: const ValueKey('districts'),
                          byDistrict: byDistrict,
                          provinceName: widget.provinceName,
                          onSelectDistrict: (d) => setState(() {
                            _goingDeeper = true;
                            _selectedDistrict = d;
                          }),
                        )),
          ),

          // ── Top breadcrumbs ────────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _GlassCard(
                  onTap: () {
                    if (_selectedDistrict != null) {
                      setState(() {
                        _goingDeeper = false;
                        _selectedDistrict = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.black.withOpacity(0.55),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _selectedDistrict ?? widget.provinceName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (_selectedDistrict == null)
                  _GlassCard(
                    onTap: () => setState(() {
                      _viewMode = _viewMode == _ViewMode.map
                          ? _ViewMode.grid
                          : _ViewMode.map;
                    }),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _viewMode == _ViewMode.map
                          ? Icons.grid_view_rounded
                          : Icons.map_outlined,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),

          // ── Action buttons ─────────────────────────────────────────────
          if (_selectedDistrict == null &&
              _viewMode == _ViewMode.map &&
              mapState.error == null)
            Positioned(
              right: 20,
              bottom: botPad + 24,
              child: _GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.palette_outlined,
                        size: 20,
                        color: Colors.black87,
                      ),
                      onPressed: showSettings,
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.black.withOpacity(0.08),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.center_focus_strong_outlined,
                        size: 20,
                        color: Colors.black87,
                      ),
                      onPressed: _resetView,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DistrictsMap extends ConsumerWidget {
  const _DistrictsMap({
    required this.provinceName,
    required this.transformController,
    required this.onSelectDistrict,
    required this.baseColor,
    required this.canvasColor,
    required this.strokeColor,
  });

  final String provinceName;
  final TransformationController transformController;
  final ValueChanged<String> onSelectDistrict;
  final Color baseColor;
  final Color canvasColor;
  final Color strokeColor;

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
            ElevatedButton(
              onPressed: () => ref
                  .read(provinceMapProvider(provinceName).notifier)
                  .loadMap(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Listener(
      onPointerUp: (e) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = renderBox.globalToLocal(e.position);

        Rect totalBounds = state.districts.first.bounds;
        for (var d in state.districts.skip(1)) {
          totalBounds = totalBounds.expandToInclude(d.bounds);
        }

        final scaleX = renderBox.size.width / totalBounds.width;
        final scaleY = renderBox.size.height / totalBounds.height;
        final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;

        final offsetX =
            (renderBox.size.width - totalBounds.width * scale) / 2 -
            totalBounds.left * scale;
        final offsetY =
            (renderBox.size.height - totalBounds.height * scale) / 2 -
            totalBounds.top * scale;

        final px = (localPos.dx - offsetX) / scale;
        final py = (localPos.dy - offsetY) / scale;
        final mapPoint = Offset(px, py);

        for (var district in state.districts) {
          if (district.path.contains(mapPoint)) {
            onSelectDistrict(district.name);
            break;
          }
        }
      },
      child: InteractiveViewer(
        transformationController: transformController,
        boundaryMargin: const EdgeInsets.all(120),
        minScale: 0.4,
        maxScale: 10.0,
        child: Center(
          child: CustomPaint(
            size: const Size(1000, 1000),
            painter: ProvinceMapPainter(
              districts: state.districts,
              combinedPath: state.combinedPath,
              districtPhotos: state.districtPhotos,
              imageLoadTimes: state.imageLoadTimes,
              currentTime: DateTime.now(),
              openTime: DateTime.now(),
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

class _DistrictsGrid extends StatelessWidget {
  final Map<String, List<PhotoItem>> byDistrict;
  final String provinceName;
  final ValueChanged<String> onSelectDistrict;

  const _DistrictsGrid({
    super.key,
    required this.byDistrict,
    required this.provinceName,
    required this.onSelectDistrict,
  });

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
                  _DistrictThumbnail(entity: newestPhoto.assetEntity!),
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

class _DistrictThumbnail extends StatelessWidget {
  final AssetEntity entity;
  const _DistrictThumbnail({required this.entity});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image?>(
      future: null, // Just for UI structure, ideally use a thumbnail widget
      builder: (context, snapshot) {
        return AssetEntityImage(
          entity,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize(400, 400),
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _DistrictPhotosGrid extends StatelessWidget {
  final List<PhotoItem> photos;
  final String districtName;
  const _DistrictPhotosGrid({
    super.key,
    required this.photos,
    required this.districtName,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 80,
        8,
        8,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        if (photo.assetEntity == null) return const SizedBox();
        return AssetEntityImage(
          photo.assetEntity!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize(300, 300),
          fit: BoxFit.cover,
        );
      },
    );
  }
}
