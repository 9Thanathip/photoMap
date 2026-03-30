import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/map_provider.dart';
import '../widgets/thailand_map_painter.dart';

const _kKeyProvinceColor = 'map_province_color';
const _kKeyCanvasColor = 'map_canvas_color';

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
  // _ColorPreset('Blush', Color(0xFFE8B4B8)),
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
  // _ColorPreset('Forest', Color(0xFF1A2A1A)),
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
    _ticker = createTicker((_) => setState(() => _currentTime = DateTime.now()))
      ..start();
    _loadColors();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    final provinceVal = prefs.getInt(_kKeyProvinceColor);
    final canvasVal = prefs.getInt(_kKeyCanvasColor);
    if (!mounted) return;
    setState(() {
      if (provinceVal != null) _provinceColor = Color(provinceVal);
      if (canvasVal != null) _canvasColor = Color(canvasVal);
    });
  }

  Future<void> _saveColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKeyProvinceColor, _provinceColor.toARGB32());
    await prefs.setInt(_kKeyCanvasColor, _canvasColor.toARGB32());
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
        onProvinceSelect: (c) {
          setState(() => _provinceColor = c);
          _saveColors();
        },
        onCanvasSelect: (c) {
          setState(() => _canvasColor = c);
          _saveColors();
        },
      ),
    );
  }

  // ── Download map as image ───────────────────────────────────────────────────

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Render at 2x for a crisp export
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapProvider);
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    final brightness = ThemeData.estimateBrightnessForColor(_provinceColor);
    final strokeColor = brightness == Brightness.dark
        ? Colors.white30
        : Colors.white;

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 15,
                    color: Colors.black.withValues(alpha: 0.55),
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
                    icon: Icons.center_focus_strong_outlined,
                    tooltip: 'Center Map',
                    onTap: _resetView,
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

// ── Settings sheet — two color preview cards, tap to edit ────────────────────

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

  void _openColorPicker(
    BuildContext context, {
    required String title,
    required Color current,
    required List<_ColorPreset> presets,
    required ValueChanged<Color> onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ColorPickerSheet(
        title: title,
        current: current,
        presets: presets,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, botPad + 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Two color cards side by side
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: _ColorCard(
                    label: 'Province',
                    color: currentProvince,
                    onTap: () => _openColorPicker(
                      context,
                      title: 'Province Color',
                      current: currentProvince,
                      presets: _kProvincePresets,
                      onSelect: onProvinceSelect,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ColorCard(
                    label: 'Background',
                    color: currentCanvas,
                    onTap: () => _openColorPicker(
                      context,
                      title: 'Background Color',
                      current: currentCanvas,
                      presets: _kCanvasPresets,
                      onSelect: onCanvasSelect,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Color preview card ────────────────────────────────────────────────────────

class _ColorCard extends StatelessWidget {
  const _ColorCard({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 14,
              bottom: 12,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.colorize_rounded, size: 14, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color picker sheet — grid + custom ───────────────────────────────────────

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({
    required this.title,
    required this.current,
    required this.presets,
    required this.onSelect,
  });

  final String title;
  final Color current;
  final List<_ColorPreset> presets;
  final ValueChanged<Color> onSelect;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _selected;
  bool _showHuePicker = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  bool get _isCustom =>
      !widget.presets.any((p) => p.color.toARGB32() == _selected.toARGB32());

  void _apply() {
    widget.onSelect(_selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, botPad + 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                // Live preview pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _selected,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _selected.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Grid or Hue picker
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _showHuePicker
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildGrid(),
            secondChild: _buildHuePicker(),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: const ui.Color.fromARGB(255, 213, 213, 213),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    const cols = 4;
    final items = [...widget.presets, null]; // null = custom slot
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: EdgeInsets.only(bottom: 24),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final preset = items[i];
          if (preset == null) {
            // Custom rainbow tile
            final customSel = _isCustom;
            return GestureDetector(
              onTap: () => setState(() => _showHuePicker = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                  border: customSel
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : null,
                ),
                child: customSel
                    ? Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                        shadows: const [Shadow(blurRadius: 4)],
                      )
                    : Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                        shadows: const [Shadow(blurRadius: 4)],
                      ),
              ),
            );
          }

          final sel = preset.color.toARGB32() == _selected.toARGB32();
          return GestureDetector(
            onTap: () => setState(() {
              _selected = preset.color;
              _showHuePicker = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: preset.color,
                borderRadius: BorderRadius.circular(16),
                border: sel
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: preset.color.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: sel
                  ? Icon(
                      Icons.check_rounded,
                      size: 22,
                      color:
                          ThemeData.estimateBrightnessForColor(preset.color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHuePicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: HueRingPicker(
            pickerColor: _selected,
            onColorChanged: (c) => setState(() => _selected = c),
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _showHuePicker = false),
          child: Text(
            'Back to presets',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
        ),
      ],
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
          child: Icon(
            icon,
            size: 20,
            color: Colors.black.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
