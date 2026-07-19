import 'dart:io';
import 'package:photo_map/core/theme/app_icons.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/common_widgets/app_snack.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'province_gallery_screen.dart';
import 'package:photo_map/features/map/presentation/widgets/province_district/districts_grid.dart';
import 'package:photo_map/features/map/presentation/widgets/province_district/districts_map.dart';
import 'package:photo_map/features/map/presentation/widgets/province_district/province_header.dart';
import '../providers/map_settings_provider.dart';
import '../providers/province_map_provider.dart';
import '../widgets/map_settings_widgets.dart';
import '../widgets/map_ui_components.dart';

class ProvinceDistrictScreen extends ConsumerStatefulWidget {
  final String countryId;
  final String provinceName;
  const ProvinceDistrictScreen({
    super.key,
    required this.countryId,
    required this.provinceName,
  });

  @override
  ConsumerState<ProvinceDistrictScreen> createState() =>
      _ProvinceDistrictScreenState();
}

class _ProvinceDistrictScreenState extends ConsumerState<ProvinceDistrictScreen>
    with SingleTickerProviderStateMixin {
  ProvinceViewMode _viewMode = ProvinceViewMode.map;
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();

  late final Ticker _ticker;
  DateTime _currentTime = DateTime.now();
  late final DateTime _openTime;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _openTime = DateTime.now();
    _ticker = createTicker((_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    })..start();

    Future.microtask(() {
      ref.read(provinceMapProvider(
        ProvinceMapParams(
          countryId: widget.countryId,
          provinceName: widget.provinceName,
        ),
      ).notifier).loadMap();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final filename =
          '${widget.provinceName}_map_${DateTime.now().millisecondsSinceEpoch}.png';

      await PhotoManager.editor.saveImage(
        bytes,
        filename: filename,
        title: filename,
        desc: 'Exported ${widget.provinceName} from Jaruek',
      );

      if (mounted) {
        AppSnack.success(context, AppLocalizations.of(context).mapSavedToPhotos);
      }
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, AppLocalizations.of(context).mapSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _share() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/${widget.provinceName}_map_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {}
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
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  void _onSelectDistrict(String districtName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProvinceGalleryScreen(
          countryId: widget.countryId,
          provinceName: widget.provinceName,
          districtName: districtName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(provinceMapProvider(
      ProvinceMapParams(
        countryId: widget.countryId,
        provinceName: widget.provinceName,
      ),
    ));
    final byDistrict = mapState.allPhotosByDistrict;
    final settings = ref.watch(mapSettingsProvider);

    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    final strokeColor = settings.strokeColor;
    final strokeWidth = settings.strokeWidth;

    return Scaffold(
      backgroundColor: settings.canvasColor,
      body: Stack(
        children: [
          // Content Area
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _viewMode == ProvinceViewMode.map
                ? RepaintBoundary(
                    key: _repaintKey,
                    child: DistrictsMap(
                      countryId: widget.countryId,
                      provinceName: widget.provinceName,
                      transformController: _transformController,
                      baseColor: settings.provinceColor,
                      canvasColor: settings.canvasColor,
                      strokeColor: strokeColor,
                      strokeWidth: strokeWidth,
                      currentTime: _currentTime,
                      openTime: _openTime,
                      onSelectDistrict: (d) => _onSelectDistrict(d),
                    ),
                  )
                : DistrictsGrid(
                    key: const ValueKey('districts'),
                    byDistrict: byDistrict,
                    provinceName: widget.provinceName,
                    onSelectDistrict: (d) => _onSelectDistrict(d),
                  ),
          ),

          // Top Background Scrim Overlay (For Status Bar readability)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
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
                      icon: AppIcons.palette_outlined,
                      tooltip: AppLocalizations.of(context).tooltipColors,
                      onTap: _showSettings,
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                    MapActionButton(
                      icon: AppIcons.center_focus_strong_outlined,
                      tooltip: AppLocalizations.of(context).tooltipCenter,
                      onTap: _resetView,
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                    MapActionButton(
                      icon: _downloading
                          ? AppIcons.hourglass_top_rounded
                          : AppIcons.download_rounded,
                      tooltip: AppLocalizations.of(context).tooltipSaveToPhotos,
                      onTap: _download,
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                    MapActionButton(
                      icon: AppIcons.ios_share,
                      tooltip: AppLocalizations.of(context).tooltipShareMap,
                      onTap: _share,
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
