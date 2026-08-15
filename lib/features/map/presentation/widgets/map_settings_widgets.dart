import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:photo_map/common_widgets/app_sheet_handle.dart';
import 'package:photo_map/common_widgets/color_picker_sheet.dart';
import 'package:photo_map/common_widgets/glass_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/core/theme/app_palette.dart';
import 'package:photo_map/features/map/presentation/providers/map_settings_provider.dart';
import 'package:photo_map/l10n/app_localizations.dart';

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

    return GlassSheet(
      child: Container(
        padding: EdgeInsets.only(bottom: botPad),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                child: Icon(
                  AppIcons.colorize_rounded,
                  size: 14,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

