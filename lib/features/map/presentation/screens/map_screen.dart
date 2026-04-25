import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import '../../../province/data/province_data.dart';
import 'package:photo_map/features/map/presentation/widgets/national_map/national_map_actions.dart';
import 'package:photo_map/features/map/presentation/widgets/national_map/national_map_header.dart';
import 'package:photo_map/features/map/presentation/widgets/national_map/province_menu_sheet.dart';
import '../providers/map_provider.dart';
import '../providers/map_settings_provider.dart';
import '../widgets/map_settings_widgets.dart';
import '../widgets/thailand_map_painter.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _currentTime = DateTime.now();
  late final DateTime _openTime;
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();

  bool _downloading = false;
  Offset? _tapDownPosition;

  // Local first-seen timestamps — set at the exact frame an image first renders,
  // so opacity always starts at 0 regardless of when the provider decoded the image.
  final Map<String, DateTime> _firstSeenTimes = {};
  static const int _staggerMs = 80;

  @override
  void initState() {
    super.initState();
    _openTime = DateTime.now();
    _ticker = createTicker((_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
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
          'thailand_map_${DateTime.now().millisecondsSinceEpoch}.png';

      await PhotoManager.editor.saveImage(
        bytes,
        filename: filename,
        title: filename,
        desc: 'Exported from Jaruek',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved to Photos'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save image'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _handleMapTap(
    BuildContext context,
    Offset globalPosition,
    List<ProvinceShape> provinces,
  ) {
    if (provinces.isEmpty) return;

    final renderBox =
        _repaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final canvasPos = renderBox.globalToLocal(globalPosition);
    final canvasSize = renderBox.size;

    Rect totalBounds = provinces.first.bounds;
    for (final p in provinces.skip(1)) {
      totalBounds = totalBounds.expandToInclude(p.bounds);
    }

    final scaleX = canvasSize.width / totalBounds.width;
    final scaleY = canvasSize.height / totalBounds.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.80;

    final offsetX =
        (canvasSize.width - totalBounds.width * scale) / 2 -
        totalBounds.left * scale;
    final offsetY =
        (canvasSize.height - totalBounds.height * scale) / 2 -
        totalBounds.top * scale;

    final px = (canvasPos.dx - offsetX) / scale;
    final py = (canvasPos.dy - offsetY) / scale;
    final provincePoint = Offset(px, py);

    for (final province in provinces) {
      if (province.path.contains(provincePoint)) {
        final prettyName = _prettyProvinceName(province.name);
        _showProvinceMenu(context, prettyName);
        return;
      }
    }
  }

  String _prettyProvinceName(String normalizedName) {
    for (final p in thaiProvinces) {
      if (p.name.replaceAll(RegExp(r'[\s-]'), '').toLowerCase() ==
          normalizedName) {
        return p.name;
      }
    }
    return normalizedName.isNotEmpty
        ? normalizedName[0].toUpperCase() + normalizedName.substring(1)
        : normalizedName;
  }

  void _showProvinceMenu(BuildContext context, String provinceName) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ProvinceMenuSheet(provinceName: provinceName),
    );
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
    final state = ref.watch(mapProvider);
    final settings = ref.watch(mapSettingsProvider);
    final gallery = ref.watch(galleryStateProvider);

    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    final strokeColor = settings.strokeColor;
    final strokeWidth = settings.strokeWidth;

    // Register first-seen time at the exact frame each province image appears.
    // This guarantees opacity starts at 0 on the first render frame, regardless
    // of when the provider finished decoding the image.
    final newKeys =
        state.provincePhotos.keys
            .where(
              (k) =>
                  state.provincePhotos[k] != null &&
                  !_firstSeenTimes.containsKey(k),
            )
            .toList()
          ..sort();
    if (newKeys.isNotEmpty) {
      final now = DateTime.now();
      for (var i = 0; i < newKeys.length; i++) {
        _firstSeenTimes[newKeys[i]] = now.add(
          Duration(milliseconds: i * _staggerMs),
        );
      }
    }

    return Scaffold(
      backgroundColor: settings.canvasColor,
      body: Stack(
        children: [
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.provinces.isEmpty)
            const Center(child: Text('No Map Data Found'))
          else
            Listener(
              onPointerDown: (e) => _tapDownPosition = e.position,
              onPointerUp: (e) {
                final down = _tapDownPosition;
                _tapDownPosition = null;
                if (down != null && (e.position - down).distance < 18) {
                  _handleMapTap(context, e.position, state.provinces);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformController,
                boundaryMargin: const EdgeInsets.all(120),
                minScale: 0.4,
                maxScale: 10.0,
                child: Center(
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: CustomPaint(
                      size: const Size(1000, 1000),
                      painter: ThailandMapPainter(
                        provinces: state.provinces,
                        combinedPath: state.combinedPath,
                        provincePhotos: state.provincePhotos,
                        imageLoadTimes: _firstSeenTimes,
                        cropRects: state.cropRects,
                        currentTime: _currentTime,
                        openTime: _openTime,
                        baseColor: settings.provinceColor,
                        strokeColor: strokeColor,
                        strokeWidth: strokeWidth,
                        canvasColor: settings.canvasColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),

          // Top Background Scrim Overlay (For Status Bar readability)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 40, // Shorter, focused on status bar area
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Header Overlay
          Positioned(
            top: topPad + 12,
            left: 20,
            child: const NationalMapHeader(),
          ),

          // Action Overlay
          Positioned(
            right: 20,
            bottom: botPad + 24,
            child: NationalMapActions(
              isDownloading: _downloading,
              onShowSettings: _showSettings,
              onResetView: _resetView,
              onDownload: _download,
            ),
          ),

          // Geocoding progress indicator
          Positioned(
            top: topPad + 12,
            right: 20,
            child: _GeocodingProgressChip(
              isGeocoding: gallery.isGeocoding,
              processed: gallery.geocodeProcessed,
              total: gallery.geocodeTotal,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeocodingProgressChip extends StatefulWidget {
  const _GeocodingProgressChip({
    required this.isGeocoding,
    required this.processed,
    required this.total,
  });

  final bool isGeocoding;
  final int processed;
  final int total;

  @override
  State<_GeocodingProgressChip> createState() => _GeocodingProgressChipState();
}

class _GeocodingProgressChipState extends State<_GeocodingProgressChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    if (widget.isGeocoding && widget.total > 0) {
      _visible = true;
      _anim.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _GeocodingProgressChip old) {
    super.didUpdateWidget(old);
    final shouldShow = widget.isGeocoding && widget.total > 0;
    if (shouldShow && !_visible) {
      _visible = true;
      _anim.forward();
    } else if (!shouldShow && _visible) {
      _anim.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final progress = widget.total > 0 ? widget.processed / widget.total : 0.0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final barBg = isDark ? Colors.white24 : Colors.black12;
    final barFg = isDark ? Colors.white : theme.colorScheme.primary;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.5,
                backgroundColor: barBg,
                valueColor: AlwaysStoppedAnimation<Color>(barFg),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.processed} / ${widget.total}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
