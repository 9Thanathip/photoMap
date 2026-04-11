import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../province/data/province_data.dart';
import '../providers/map_provider.dart';
import '../providers/map_settings_provider.dart';
import '../widgets/map_settings_widgets.dart';
import '../widgets/thailand_map_painter.dart';
import 'province_district_screen.dart';
import 'province_gallery_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _currentTime = DateTime.now();
  late final DateTime _openTime;
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();

  bool _downloading = false;
  Offset? _tapDownPosition;

  @override
  void initState() {
    super.initState();
    _openTime = DateTime.now();
    _ticker = createTicker((_) => setState(() => _currentTime = DateTime.now()))
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transformController.dispose();
    super.dispose();
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
        desc: 'Exported from Photo Map',
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
      builder: (ctx) {
        final theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  provinceName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withAlpha(80),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('View by Districts'),
              subtitle: const Text('Browse photos by district'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProvinceDistrictScreen(provinceName: provinceName),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('View Gallery'),
              subtitle: const Text('All photos in this province'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProvinceGalleryScreen(provinceName: provinceName),
                  ),
                );
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        );
      },
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
                        imageLoadTimes: state.imageLoadTimes,
                        currentTime: _currentTime,
                        openTime: _openTime,
                        baseColor: settings.provinceColor,
                        strokeColor: strokeColor,
                        canvasColor: settings.canvasColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            top: topPad + 12,
            left: 20,
            child: _GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 15,
                    color: Colors.black.withOpacity(0.55),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Thailand',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 20,
            bottom: botPad + 24,
            child: _GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.palette_outlined,
                    tooltip: 'Background',
                    onTap: _showSettings,
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.black.withOpacity(0.08),
                  ),
                  _ActionButton(
                    icon: Icons.center_focus_strong_outlined,
                    tooltip: 'Center Map',
                    onTap: _resetView,
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.black.withOpacity(0.08),
                  ),
                  _ActionButton(
                    icon: _downloading
                        ? Icons.hourglass_top_rounded
                        : Icons.download_rounded,
                    tooltip: 'Save to Photos',
                    onTap: _download,
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
  const _GlassCard({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.black87),
      onPressed: onTap,
      tooltip: tooltip,
    );
  }
}
