import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';

class ColorPreset {
  const ColorPreset(this.label, this.color);
  final String label;
  final Color color;
}

const kProvincePresets = [
  ColorPreset('Stone', Color(0xFFD9D9D9)),
  ColorPreset('Warm Sand', Color(0xFFE8D5B7)),
  ColorPreset('Sage', Color(0xFFB2C9AD)),
  ColorPreset('Sky', Color(0xFFB8D4E8)),
  ColorPreset('Slate', Color(0xFF7A8BA0)),
  ColorPreset('Charcoal', Color(0xFF3A3A3A)),
  ColorPreset('Ink', Color(0xFF1A1A2E)),
];

const kCanvasPresets = [
  ColorPreset('Light', Color(0xFFF0F0F5)),
  ColorPreset('Cream', Color(0xFFF5F0E8)),
  ColorPreset('Mint', Color(0xFFEDF5EF)),
  ColorPreset('Ice', Color(0xFFEAF2F8)),
  ColorPreset('Blush', Color(0xFFF8EEF0)),
  ColorPreset('Dark', Color(0xFF1C1C1E)),
  ColorPreset('Midnight', Color(0xFF0D1B2A)),
];

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
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
    required List<ColorPreset> presets,
    required ValueChanged<Color> onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ColorPickerSheet(
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
          const AppSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: ColorCard(
                    label: 'Province',
                    color: currentProvince,
                    onTap: () => _openColorPicker(
                      context,
                      title: 'Province Color',
                      current: currentProvince,
                      presets: kProvincePresets,
                      onSelect: onProvinceSelect,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ColorCard(
                    label: 'Background',
                    color: currentCanvas,
                    onTap: () => _openColorPicker(
                      context,
                      title: 'Background Color',
                      current: currentCanvas,
                      presets: kCanvasPresets,
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

class ColorCard extends StatelessWidget {
  const ColorCard({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final textColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black54;

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
              color: color.withOpacity(0.4),
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
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
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

class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    required this.title,
    required this.current,
    required this.presets,
    required this.onSelect,
  });

  final String title;
  final Color current;
  final List<ColorPreset> presets;
  final ValueChanged<Color> onSelect;

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late Color _selected;
  bool _showHuePicker = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  bool get _isCustom => !widget.presets.any((p) => p.color.value == _selected.value);

  void _apply() {
    widget.onSelect(_selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _selected,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _showHuePicker ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _buildGrid(),
            secondChild: _buildHuePicker(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD5D5D5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Apply', style: TextStyle(color: Colors.black87)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: widget.presets.length + 1,
      itemBuilder: (_, i) {
        if (i == widget.presets.length) {
          return GestureDetector(
            onTap: () => setState(() => _showHuePicker = true),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red]),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          );
        }
        final p = widget.presets[i];
        final isSel = p.color.value == _selected.value;
        return GestureDetector(
          onTap: () => setState(() => _selected = p.color),
          child: Container(
            decoration: BoxDecoration(
              color: p.color,
              borderRadius: BorderRadius.circular(16),
              border: isSel ? Border.all(color: Colors.blue, width: 3) : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHuePicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _HueSlider(
            color: _selected,
            onChanged: (c) => setState(() => _selected = c),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _showHuePicker = false),
          child: const Text('Back to presets'),
        ),
      ],
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => _updateColor(context, details.localPosition),
      onPanDown: (details) => _updateColor(context, details.localPosition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adjust Hue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
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
            ),
            child: CustomPaint(
              painter: _SliderThumbPainter(HSVColor.fromColor(color).hue),
            ),
          ),
        ],
      ),
    );
  }

  void _updateColor(BuildContext context, Offset localPos) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final percent = (localPos.dx / width).clamp(0.0, 1.0);
    final hue = percent * 360.0;
    onChanged(HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor());
  }
}

class _SliderThumbPainter extends CustomPainter {
  _SliderThumbPainter(this.hue);
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final x = (hue / 360.0) * size.width;
    final center = Offset(x, size.height / 2);

    // White border/glow
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // The thumb itself
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor()
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SliderThumbPainter old) => old.hue != hue;
}
