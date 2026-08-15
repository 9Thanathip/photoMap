import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/common_widgets/glass_sheet.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/core/theme/app_palette.dart';
import 'package:photo_map/l10n/app_localizations.dart';

/// A named colour offered up-front in a [ColorPickerSheet].
class ColorPreset {
  const ColorPreset(this.label, this.color);
  final String label;
  final Color color;
}

class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    required this.title,
    required this.current,
    required this.presets,
    required this.onSelect,
    this.startCustom = false,
  });

  final String title;
  final Color current;
  final List<ColorPreset> presets;
  final ValueChanged<Color> onSelect;

  /// Opens straight on the free-colour editor. For callers that already show
  /// their presets on the screen behind the sheet, so the grid would just be
  /// the same choices twice.
  final bool startCustom;

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late Color _selected;
  late bool _showHuePicker;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _showHuePicker = widget.startCustom;
  }

  void _apply() {
    widget.onSelect(_selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
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

          // 2D saturation/brightness field — drag anywhere to pick.
          _SVField(
            hue: _hsv.hue,
            saturation: _hsv.saturation,
            value: _hsv.value,
            thumbColor: color,
            onChanged: (s, v) => _commit(_hsv.withSaturation(s).withValue(v)),
          ),
          const SizedBox(height: 18),

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

          // Flexible because the two labels together are wider than a 400pt
          // phone in English, which overflowed the row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(AppIcons.grid_view_rounded, size: 16),
                  label: Text(
                    l10n.mapBackToPresets,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Flexible(
                child: TextButton.icon(
                  onPressed: () => _commit(HSVColor.fromColor(widget.initial)),
                  icon: const Icon(AppIcons.refresh_rounded, size: 16),
                  label: Text(
                    l10n.mapResetColor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.55),
                  ),
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

/// 2D saturation × brightness field. X = saturation (0 left → 1 right),
/// Y = brightness (1 top → 0 bottom). Drag anywhere to pick both at once.
class _SVField extends StatelessWidget {
  const _SVField({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.thumbColor,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final Color thumbColor;
  final void Function(double saturation, double value) onChanged;

  static const double _height = 200;
  static const double _radius = 18;

  void _handle(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
    onChanged(s, v);
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final thumbOnDark =
        ThemeData.estimateBrightnessForColor(thumbColor) == Brightness.dark;

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, _height);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _handle(d.localPosition, size),
            onPanStart: (d) => _handle(d.localPosition, size),
            onPanUpdate: (d) => _handle(d.localPosition, size),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: Stack(
                children: [
                  // Base hue → white (saturation), then → black (brightness).
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, hueColor],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_radius),
                        border: Border.all(
                          color: onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  // Thumb
                  Positioned(
                    left: saturation * size.width - 11,
                    top: (1 - value) * _height - 11,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: thumbColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: thumbOnDark ? Colors.white : Colors.black,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
