import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'district_gallery_screen.dart';
import 'package:photo_map/features/map/presentation/widgets/province_district/districts_grid.dart';
import 'package:photo_map/features/map/presentation/widgets/province_district/districts_map.dart';
import 'package:photo_map/features/map/presentation/widgets/province_district/province_header.dart';
import '../providers/map_settings_provider.dart';
import '../providers/province_map_provider.dart';
import '../widgets/map_settings_widgets.dart';
import '../widgets/map_ui_components.dart';

class ProvinceDistrictScreen extends ConsumerStatefulWidget {
  final String provinceName;
  const ProvinceDistrictScreen({super.key, required this.provinceName});

  @override
  ConsumerState<ProvinceDistrictScreen> createState() =>
      _ProvinceDistrictScreenState();
}

class _ProvinceDistrictScreenState extends ConsumerState<ProvinceDistrictScreen>
    with SingleTickerProviderStateMixin {
  ProvinceViewMode _viewMode = ProvinceViewMode.map;
  final TransformationController _transformController =
      TransformationController();

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

  void _onSelectDistrict(String districtName, Map<String, List<PhotoItem>> byDistrict) {
    final photos = List<PhotoItem>.from(byDistrict[districtName] ?? [])
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DistrictGalleryScreen(
          provinceName: widget.provinceName,
          districtName: districtName,
          photos: photos,
        ),
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

    final brightness = ThemeData.estimateBrightnessForColor(
      settings.provinceColor,
    );
    final strokeColor = brightness == Brightness.dark
        ? Colors.white30
        : Colors.white;

    return Scaffold(
      backgroundColor: settings.canvasColor,
      body: Stack(
        children: [
          // Content Area
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _viewMode == ProvinceViewMode.map
                ? DistrictsMap(
                    provinceName: widget.provinceName,
                    transformController: _transformController,
                    baseColor: settings.provinceColor,
                    canvasColor: settings.canvasColor,
                    strokeColor: strokeColor,
                    currentTime: _currentTime,
                    openTime: _openTime,
                    onSelectDistrict: (d) => _onSelectDistrict(d, byDistrict),
                  )
                : DistrictsGrid(
                    key: const ValueKey('districts'),
                    byDistrict: byDistrict,
                    provinceName: widget.provinceName,
                    onSelectDistrict: (d) => _onSelectDistrict(d, byDistrict),
                  ),
          ),

          // Breadcrumbs Header
          Positioned(
            top: topPad + 12,
            left: 20,
            right: 20,
            child: ProvinceHeader(
              title: widget.provinceName,
              viewMode: _viewMode,
              isSelectingDistrict: false,
              onBack: () => Navigator.pop(context),
              onToggleMode: () => setState(() {
                _viewMode = _viewMode == ProvinceViewMode.map
                    ? ProvinceViewMode.grid
                    : ProvinceViewMode.map;
              }),
            ),
          ),

          // Action Controls (Only in Map View)
          if (_viewMode == ProvinceViewMode.map && mapState.error == null)
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
