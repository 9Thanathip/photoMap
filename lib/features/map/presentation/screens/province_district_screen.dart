import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:photo_map/common_widgets/app_button.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import '../providers/map_settings_provider.dart';
import '../providers/province_map_provider.dart';
import '../widgets/map_settings_widgets.dart';
import '../widgets/map_ui_components.dart';
import '../widgets/province_map_painter.dart';

enum _ViewMode { map, grid }

class ProvinceDistrictScreen extends ConsumerStatefulWidget {
  final String provinceName;
  const ProvinceDistrictScreen({super.key, required this.provinceName});

  @override
  ConsumerState<ProvinceDistrictScreen> createState() => _ProvinceDistrictScreenState();
}

class _ProvinceDistrictScreenState extends ConsumerState<ProvinceDistrictScreen>
    with SingleTickerProviderStateMixin {
  _ViewMode _viewMode = _ViewMode.map;
  String? _selectedDistrict;
  bool _goingDeeper = false;
  final TransformationController _transformController = TransformationController();
  
  late final Ticker _ticker;
  DateTime _currentTime = DateTime.now();
  late final DateTime _openTime;

  @override
  void initState() {
    super.initState();
    _openTime = DateTime.now();
    _ticker = createTicker((_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    })..start();
    
    Future.microtask(() {
      ref.read(provinceMapProvider(widget.provinceName).notifier).loadMap();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
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

  void _showSettings() {
    final settings = ref.read(mapSettingsProvider);
    final notifier = ref.read(mapSettingsProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(
        currentProvince: settings.provinceColor,
        currentCanvas: settings.canvasColor,
        onProvinceSelect: notifier.updateProvinceColor,
        onCanvasSelect: notifier.updateCanvasColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(provinceMapProvider(widget.provinceName));
    final byDistrict = mapState.allPhotosByDistrict;
    final settings = ref.watch(mapSettingsProvider);

    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    final brightness = ThemeData.estimateBrightnessForColor(settings.provinceColor);
    final strokeColor = brightness == Brightness.dark ? Colors.white30 : Colors.white;

    return Scaffold(
      backgroundColor: settings.canvasColor,
      body: Stack(
        children: [
          // Content Area
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedDistrict != null
                ? Container(
                    color: Colors.white,
                    child: _DistrictPhotosGrid(
                      key: ValueKey(_selectedDistrict),
                      photos: List<PhotoItem>.from(byDistrict[_selectedDistrict] ?? [])
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
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
                        currentTime: _currentTime,
                        openTime: _openTime,
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

          // Breadcrumbs Header
          Positioned(
            top: topPad + 12,
            left: 20,
            right: 20,
            child: _ProvinceHeader(
              title: _selectedDistrict ?? widget.provinceName,
              viewMode: _viewMode,
              isSelectingDistrict: _selectedDistrict != null,
              onBack: () {
                if (_selectedDistrict != null) {
                  setState(() {
                    _goingDeeper = false;
                    _selectedDistrict = null;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
              onToggleMode: () => setState(() {
                _viewMode = _viewMode == _ViewMode.map ? _ViewMode.grid : _ViewMode.map;
              }),
            ),
          ),

          // Action Controls (Only in Map View)
          if (_selectedDistrict == null && _viewMode == _ViewMode.map && mapState.error == null)
            Positioned(
              right: 20,
              bottom: botPad + 24,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MapActionButton(
                      icon: Icons.palette_outlined,
                      tooltip: 'Colors',
                      onTap: _showSettings,
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.black.withOpacity(0.08),
                    ),
                    MapActionButton(
                      icon: Icons.center_focus_strong_outlined,
                      tooltip: 'Center',
                      onTap: _resetView,
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

class _ProvinceHeader extends StatelessWidget {
  const _ProvinceHeader({
    required this.title,
    required this.viewMode,
    required this.isSelectingDistrict,
    required this.onBack,
    required this.onToggleMode,
  });

  final String title;
  final _ViewMode viewMode;
  final bool isSelectingDistrict;
  final VoidCallback onBack;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassCard(
          onTap: onBack,
          padding: const EdgeInsets.all(10),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                    title,
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
        if (!isSelectingDistrict) ...[
          const SizedBox(width: 10),
          GlassCard(
            onTap: onToggleMode,
            padding: const EdgeInsets.all(10),
            child: Icon(
              viewMode == _ViewMode.map ? Icons.grid_view_rounded : Icons.map_outlined,
              size: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ],
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
              onPressed: () =>
                  ref.read(provinceMapProvider(provinceName).notifier).loadMap(),
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
            (renderBox.size.width - totalBounds.width * scale) / 2 - totalBounds.left * scale;
        final offsetY =
            (renderBox.size.height - totalBounds.height * scale) / 2 - totalBounds.top * scale;

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

class _DistrictsGrid extends StatelessWidget {
  const _DistrictsGrid({
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
    final districts = byDistrict.keys.where((d) => d != 'Unknown').toList()..sort();

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
  const _DistrictThumbnail({required this.entity});
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

class _DistrictPhotosGrid extends StatelessWidget {
  const _DistrictPhotosGrid({
    super.key,
    required this.photos,
    required this.districtName,
  });

  final List<PhotoItem> photos;
  final String districtName;

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
