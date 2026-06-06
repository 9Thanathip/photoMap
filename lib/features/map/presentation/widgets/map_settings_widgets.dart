import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/core/theme/app_palette.dart';
import 'package:photo_map/features/map/presentation/providers/map_settings_provider.dart';
import 'package:photo_map/l10n/app_localizations.dart';

class ColorPreset {
  const ColorPreset(this.label, this.color);
  final String label;
  final Color color;
}

const kStrokePresets = [
  ColorPreset('White', Colors.white),
  ColorPreset('Light', Palette.mapLight),
  ColorPreset('Silver', Palette.mapSilver),
  ColorPreset('Warm', Palette.mapWarm),
  ColorPreset('Gold', Palette.gold400),
  ColorPreset('Black', Palette.mapBlack),
  ColorPreset('Dark', Palette.mapDark),
];

const kProvincePresets = [
  ColorPreset('Stone', Palette.mapStone),
  ColorPreset('Warm Sand', Palette.mapWarmSand),
  ColorPreset('Sage', Palette.mapSage),
  ColorPreset('Sky', Palette.mapSky),
  ColorPreset('Slate', Palette.mapSlate),
  ColorPreset('Charcoal', Palette.mapCharcoal),
  ColorPreset('Ink', Palette.mapInk),
];

const kCanvasPresets = [
  ColorPreset('Light', Palette.mapCanvasLight),
  ColorPreset('Cream', Palette.mapCanvasCream),
  ColorPreset('Mint', Palette.mapCanvasMint),
  ColorPreset('Ice', Palette.mapCanvasIce),
  ColorPreset('Blush', Palette.mapCanvasBlush),
  ColorPreset('Dark', Palette.mapCanvasDark),
  ColorPreset('Midnight', Palette.mapCanvasMidnight),
];

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(mapSettingsProvider);
    final notifier = ref.read(mapSettingsProvider.notifier);
    final botPad = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, botPad + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHandle(),
          // ── Fill colors ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ColorCard(
                    label: l10n.mapSettingsProvince,
                    color: settings.provinceColor,
                    onTap: () => _openColorPicker(
                      context,
                      title: l10n.mapSettingsProvinceColor,
                      current: settings.provinceColor,
                      presets: kProvincePresets,
                      onSelect: notifier.updateProvinceColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ColorCard(
                    label: l10n.mapSettingsBackground,
                    color: settings.canvasColor,
                    onTap: () => _openColorPicker(
                      context,
                      title: l10n.mapSettingsBackgroundColor,
                      current: settings.canvasColor,
                      presets: kCanvasPresets,
                      onSelect: notifier.updateCanvasColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Border controls ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.mapSettingsBorder,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Color row
                  Row(
                    children: [
                      Text(
                        l10n.mapSettingsColor,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _openColorPicker(
                          context,
                          title: l10n.mapSettingsBorderColor,
                          current: settings.strokeColor,
                          presets: kStrokePresets,
                          onSelect: notifier.updateStrokeColor,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: settings.strokeColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Width slider
                  Row(
                    children: [
                      Text(
                        l10n.mapSettingsWidth,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        settings.strokeWidth.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: theme.colorScheme.onSurface,
                      inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      thumbColor: theme.colorScheme.onSurface,
                    ),
                    child: Slider(
                      value: settings.strokeWidth,
                      min: 0.3,
                      max: 3.0,
                      divisions: 27,
                      onChanged: (v) {
                        final stepped = (v * 10).round() / 10;
                        if (stepped != (settings.strokeWidth * 10).round() / 10) {
                          HapticFeedback.selectionClick();
                        }
                        notifier.updateStrokeWidth(v);
                      },
                    ),
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
    final isDark =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final textColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black54;

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
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
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

  void _apply() {
    widget.onSelect(_selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
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
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            crossFadeState: _showHuePicker
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
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
                  backgroundColor: Palette.mapPickerBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  AppLocalizations.of(context).mapSettingsApply,
                  style: const TextStyle(color: Colors.black87),
                ),
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
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.red,
                  ],
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          );
        }
        final p = widget.presets[i];
        final isSel = p.color.toARGB32() == _selected.toARGB32();
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
          child: Text(AppLocalizations.of(context).mapBackToPresets),
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
