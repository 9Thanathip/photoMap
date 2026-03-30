import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/map_provider.dart';
import '../widgets/thailand_map_painter.dart';

class _ColorPreset {
  const _ColorPreset(this.label, this.color);
  final String label;
  final Color color;
}

// Province (map fill) color presets
const _kProvincePresets = [
  _ColorPreset('Stone', Color(0xFFD9D9D9)),
  _ColorPreset('Warm Sand', Color(0xFFE8D5B7)),
  _ColorPreset('Sage', Color(0xFFB2C9AD)),
  _ColorPreset('Sky', Color(0xFFB8D4E8)),
  _ColorPreset('Blush', Color(0xFFE8B4B8)),
  _ColorPreset('Slate', Color(0xFF7A8BA0)),
  _ColorPreset('Charcoal', Color(0xFF3A3A3A)),
  _ColorPreset('Ink', Color(0xFF1A1A2E)),
];

// Screen / canvas background color presets
const _kCanvasPresets = [
  _ColorPreset('Light', Color(0xFFF0F0F5)),
  _ColorPreset('Cream', Color(0xFFF5F0E8)),
  _ColorPreset('Mint', Color(0xFFEDF5EF)),
  _ColorPreset('Ice', Color(0xFFEAF2F8)),
  _ColorPreset('Blush', Color(0xFFF8EEF0)),
  _ColorPreset('Dark', Color(0xFF1C1C1E)),
  _ColorPreset('Midnight', Color(0xFF0D1B2A)),
  _ColorPreset('Forest', Color(0xFF1A2A1A)),
];

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

  Color _provinceColor = _kProvincePresets.first.color;
  Color _canvasColor = _kCanvasPresets.first.color;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _openTime = DateTime.now();
    _ticker =
        createTicker((_) => setState(() => _currentTime = DateTime.now()))
          ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // ── Settings sheet ──────────────────────────────────────────────────────────

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(
        currentProvince: _provinceColor,
        currentCanvas: _canvasColor,
        onProvinceSelect: (c) => setState(() => _provinceColor = c),
        onCanvasSelect: (c) => setState(() => _canvasColor = c),
      ),
    );
  }

  // ── Download map as image ───────────────────────────────────────────────────

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Render at 2x for a crisp export
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save image'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapProvider);
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    final brightness = ThemeData.estimateBrightnessForColor(_provinceColor);
    final strokeColor =
        brightness == Brightness.dark ? Colors.white30 : Colors.white;

    return Scaffold(
      backgroundColor: _canvasColor,
      body: Stack(
        children: [
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.provinces.isEmpty)
            const Center(child: Text('No Map Data Found'))
          else
            InteractiveViewer(
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
                      baseColor: _provinceColor,
                      strokeColor: strokeColor,
                      canvasColor: _canvasColor,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),

          // ── Top label ──────────────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 20,
            child: _GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined,
                      size: 15,
                      color: Colors.black.withValues(alpha: 0.55)),
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

          // ── Action buttons bottom-right ────────────────────────────────────
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
                    color: Colors.black.withValues(alpha: 0.08),
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

// ── Settings sheet ────────────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.currentProvince,
    required this.currentCanvas,
    required this.onProvinceSelect,
    required this.onCanvasSelect,
  });

  final Color currentProvince;
  final Color currentCanvas;
  final ValueChanged<Color> onProvinceSelect;
  final ValueChanged<Color> onCanvasSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Province color section
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Province Color',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          _ColorGrid(
            presets: _kProvincePresets,
            current: currentProvince,
            onSelect: onProvinceSelect,
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Divider(
                height: 1,
                color: Colors.black.withValues(alpha: 0.07)),
          ),
          // Canvas / background color section
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Background Color',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          _ColorGrid(
            presets: _kCanvasPresets,
            current: currentCanvas,
            onSelect: onCanvasSelect,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Reusable color swatch grid ────────────────────────────────────────────────

class _ColorGrid extends StatelessWidget {
  const _ColorGrid({
    required this.presets,
    required this.current,
    required this.onSelect,
  });

  final List<_ColorPreset> presets;
  final Color current;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: presets.map((preset) {
          final selected = preset.color.toARGB32() == current.toARGB32();
          return GestureDetector(
            onTap: () => onSelect(preset.color),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: preset.color,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black.withValues(alpha: 0.08),
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: preset.color.withValues(alpha: 0.35),
                        blurRadius: selected ? 10 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          color:
                              ThemeData.estimateBrightnessForColor(preset.color) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                          size: 18,
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  preset.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Frosted glass card ────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon,
              size: 20, color: Colors.black.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}
