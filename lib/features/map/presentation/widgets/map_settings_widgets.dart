import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
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
      useRootNavigator: true,
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
      padding: EdgeInsets.only(bottom: botPad),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
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
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              AppIcons.chevron_right_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: theme.colorScheme.onSurface,
                      inactiveTrackColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.15),
                      thumbColor: theme.colorScheme.onSurface,
                    ),
                    child: Slider(
                      value: settings.strokeWidth,
                      min: 0.3,
                      max: 3.0,
                      divisions: 27,
                      onChanged: (v) {
                        final stepped = (v * 10).round() / 10;
                        if (stepped !=
                            (settings.strokeWidth * 10).round() / 10) {
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
                child: Icon(AppIcons.colorize_rounded, size: 14, color: textColor),
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
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              child: const Icon(AppIcons.add, color: Colors.white),
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
    return _HsvPicker(
      color: _selected,
      initial: widget.current,
      onChanged: (c) => setState(() => _selected = c),
      onBack: () => setState(() => _showHuePicker = false),
    );
  }
}

/// Three-channel (H/S/V) custom-color editor. The hue track shows the full
/// rainbow; the saturation and value tracks update their gradients live to
/// reflect the other channels, so the slider you're touching always paints
/// what the result will look like.
class _HsvPicker extends StatefulWidget {
  const _HsvPicker({
    required this.color,
    required this.initial,
    required this.onChanged,
    required this.onBack,
  });

  final Color color;
  final Color initial;
  final ValueChanged<Color> onChanged;
  final VoidCallback onBack;

  @override
  State<_HsvPicker> createState() => _HsvPickerState();
}

class _HsvPickerState extends State<_HsvPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant _HsvPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if the parent swapped in a different color (e.g. preset selected
    // again before opening the custom picker).
    if (oldWidget.color != widget.color && widget.color != _hsv.toColor()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _commit(HSVColor next) {
    setState(() => _hsv = next);
    widget.onChanged(next.toColor());
  }

  String _hex(Color c) {
    String pad(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${pad((c.r * 255).round())}${pad((c.g * 255).round())}${pad((c.b * 255).round())}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = _hsv.toColor();
    final onSurface = theme.colorScheme.onSurface;
    final isDarkOnPreview =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final previewTextColor = isDarkOnPreview
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Big preview ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 92,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: onSurface.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _hex(color),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: previewTextColor,
                letterSpacing: 2.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 22),

          _ChannelSlider(
            label: l10n.mapHue,
            valueText: '${_hsv.hue.round()}°',
            position: _hsv.hue / 360.0,
            trackGradient: const LinearGradient(
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
            thumbColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
            onChanged: (p) => _commit(_hsv.withHue(p * 360)),
          ),
          const SizedBox(height: 18),

          _ChannelSlider(
            label: l10n.mapSaturation,
            valueText: '${(_hsv.saturation * 100).round()}%',
            position: _hsv.saturation,
            trackGradient: LinearGradient(
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
            ),
            thumbColor: color,
            onChanged: (p) => _commit(_hsv.withSaturation(p)),
          ),
          const SizedBox(height: 18),

          _ChannelSlider(
            label: l10n.mapBrightness,
            valueText: '${(_hsv.value * 100).round()}%',
            position: _hsv.value,
            trackGradient: LinearGradient(
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
            ),
            thumbColor: color,
            onChanged: (p) => _commit(_hsv.withValue(p)),
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(AppIcons.grid_view_rounded, size: 16),
                label: Text(l10n.mapBackToPresets),
                style: TextButton.styleFrom(
                  foregroundColor: onSurface.withValues(alpha: 0.7),
                ),
              ),
              TextButton.icon(
                onPressed: () => _commit(HSVColor.fromColor(widget.initial)),
                icon: const Icon(AppIcons.refresh_rounded, size: 16),
                label: Text(l10n.mapResetColor),
                style: TextButton.styleFrom(
                  foregroundColor: onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.valueText,
    required this.position,
    required this.trackGradient,
    required this.thumbColor,
    required this.onChanged,
  });

  /// Channel name shown above the track.
  final String label;

  /// Right-aligned numeric readout (e.g. `120°`, `42%`).
  final String valueText;

  /// Normalised position 0..1 (left = 0).
  final double position;

  final Gradient trackGradient;

  /// Fill color of the thumb. The HSV picker passes the *current* channel
  /// extreme so the thumb visually matches what it sets.
  final Color thumbColor;

  final ValueChanged<double> onChanged;

  static const double _trackHeight = 14;
  static const double _thumbRadius = 13;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onSurface.withValues(alpha: 0.75),
                letterSpacing: -0.1,
              ),
            ),
            const Spacer(),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onSurface.withValues(alpha: 0.5),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            void update(Offset local) {
              final p = (local.dx / width).clamp(0.0, 1.0);
              if (p != position) HapticFeedback.selectionClick();
              onChanged(p);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => update(d.localPosition),
              onPanUpdate: (d) => update(d.localPosition),
              onTapDown: (d) => update(d.localPosition),
              child: SizedBox(
                height: _thumbRadius * 2,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: _trackHeight,
                      decoration: BoxDecoration(
                        gradient: trackGradient,
                        borderRadius: BorderRadius.circular(_trackHeight / 2),
                        border: Border.all(
                          color: onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      left:
                          (width - _thumbRadius * 2) * position.clamp(0.0, 1.0),
                      child: _Thumb(color: thumbColor, radius: _thumbRadius),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
