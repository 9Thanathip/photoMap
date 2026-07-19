import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/common_widgets/app_snack.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../providers/gallery_notifier.dart';
import '../../../utils/color_matrix_utils.dart';
import 'film_effects.dart';

enum _EditMode { presets, adjust }

enum _AdjustTool {
  exposure,
  contrast,
  saturation,
  temperature,
  tint,
  fade,
  grain,
  vignette,
  lightLeak,
}

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({
    super.key,
    required this.photo,
    required this.heroTag,
  });

  final PhotoItem photo;
  final String heroTag;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  _EditMode _mode = _EditMode.presets;
  _AdjustTool? _activeTool;

  // State
  int _presetIndex = 0;
  double _exposure = 0.0; // -1.0 to 1.0
  double _contrast = 1.0; // 0.5 to 1.5
  double _saturation = 1.0; // 0.0 to 2.0
  double _temperature = 0.0; // -1.0 to 1.0
  double _tint = 0.0; // -1.0 to 1.0

  // Film overlay effects, 0.0 (off) .. 1.0 (strong).
  double _fade = 0.0; // lifted/faded shadows (baked into the colour matrix)
  double _grain = 0.0; // film grain overlay
  double _vignette = 0.0; // darkened edges overlay
  double _lightLeak = 0.0; // warm light-leak overlay
  Alignment _lightLeakDir = Alignment.topRight; // leak origin corner

  bool _showOriginal = false;
  bool _saving = false;

  // Persistent so the horizontal tool strip keeps its scroll offset when the
  // slider opens/closes (the AnimatedSwitcher otherwise rebuilds it at 0).
  final ScrollController _toolsScroll = ScrollController();

  @override
  void dispose() {
    _toolsScroll.dispose();
    super.dispose();
  }

  ColorMatrix get _combinedMatrix {
    if (_showOriginal) return ColorMatrix.identity;

    ColorMatrix m = kFilmPresets[_presetIndex].matrix;
    if (_exposure != 0) m = m.multiply(ColorMatrix.exposure(_exposure));
    if (_contrast != 1.0) m = m.multiply(ColorMatrix.contrast(_contrast));
    if (_saturation != 1.0) m = m.multiply(ColorMatrix.saturation(_saturation));
    if (_temperature != 0) m = m.multiply(ColorMatrix.temperature(_temperature));
    if (_tint != 0) m = m.multiply(ColorMatrix.tint(_tint));
    if (_fade != 0) m = m.multiply(ColorMatrix.fade(_fade));

    return m;
  }

  void _resetAdjustments() {
    setState(() {
      _exposure = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _temperature = 0.0;
      _tint = 0.0;
      _fade = 0.0;
      _grain = 0.0;
      _vignette = 0.0;
      _lightLeak = 0.0;
      _lightLeakDir = Alignment.topRight;
    });
  }

  bool get _hasAdjustments =>
      _exposure != 0.0 ||
      _contrast != 1.0 ||
      _saturation != 1.0 ||
      _temperature != 0.0 ||
      _tint != 0.0 ||
      _fade != 0.0 ||
      _grain != 0.0 ||
      _vignette != 0.0 ||
      _lightLeak != 0.0;

  Future<void> _save() async {
    final asset = widget.photo.assetEntity;
    if (asset == null || _saving) return;
    setState(() => _saving = true);

    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    try {
      final origin = await asset.originBytes;
      if (origin == null) throw StateError('Original bytes unavailable.');

      final codec = await ui.instantiateImageCodec(origin);
      final frame = await codec.getNextFrame();
      final source = frame.image;
      final w = source.width.toDouble();
      final h = source.height.toDouble();
      final rect = Rect.fromLTWH(0, 0, w, h);

      // Bake the same pipeline the preview shows: colour matrix first, then the
      // film overlays on top, all at full source resolution.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, rect);
      canvas.drawImage(
        source,
        Offset.zero,
        Paint()
          ..colorFilter = ColorFilter.matrix(_combinedMatrix.matrix)
          ..filterQuality = FilterQuality.high,
      );
      paintFilmOverlays(
        canvas,
        rect,
        vignette: _vignette,
        lightLeak: _lightLeak,
        grain: _grain,
        lightLeakDirection: _lightLeakDir,
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(source.width, source.height);
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Failed to encode edited image.');

      final filename = 'jaruek_${DateTime.now().millisecondsSinceEpoch}.png';
      await PhotoManager.editor.saveImage(
        png.buffer.asUint8List(),
        filename: filename,
        title: filename,
        desc: 'Edited in Jaruek',
      );

      AppSnack.showOnOverlay(overlay, l10n.editorSaved);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      AppSnack.showOnOverlay(overlay, l10n.editorSaveFailed,
          type: AppSnackType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _buildImageViewport(),
              ),
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 15)),
          ),
          Text(
            _mode == _EditMode.presets ? l10n.editorPresets : l10n.editorAdjust,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.commonDone,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewport() {
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _showOriginal = true),
      onLongPressEnd: (_) => setState(() => _showOriginal = false),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: widget.photo.assetEntity != null
              ? CustomPaint(
                  // foregroundPainter paints over exactly the image's rendered
                  // box, so grain/vignette/leak align with the photo (not the
                  // letterbox bars).
                  foregroundPainter: _showOriginal
                      ? null
                      : FilmOverlayPainter(
                          vignette: _vignette,
                          lightLeak: _lightLeak,
                          grain: _grain,
                          lightLeakDirection: _lightLeakDir,
                        ),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_combinedMatrix.matrix),
                    child: Image(
                      image: AssetEntityImageProvider(
                        widget.photo.assetEntity!,
                        isOriginal: true,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _mode == _EditMode.presets
                    ? _buildPresetsList()
                    : (_activeTool != null
                        ? _buildSlider()
                        : _buildAdjustTools()),
              ),
            ),
          ),
          if (_activeTool == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BottomTab(
                    title: AppLocalizations.of(context)
                        .editorPresets
                        .toUpperCase(),
                    isActive: _mode == _EditMode.presets,
                    onTap: () => setState(() => _mode = _EditMode.presets),
                  ),
                  _BottomTab(
                    title:
                        AppLocalizations.of(context).editorAdjust.toUpperCase(),
                    isActive: _mode == _EditMode.adjust,
                    onTap: () => setState(() => _mode = _EditMode.adjust),
                    showDot: _hasAdjustments,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetsList() {
    return ListView.builder(
      key: const ValueKey('presets'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: kFilmPresets.length,
      itemBuilder: (context, i) {
        final preset = kFilmPresets[i];
        final isSelected = _presetIndex == i;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _presetIndex = i);
          },
          child: Container(
            width: 72,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  preset.id,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 56,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 2 : 4),
                    child: widget.photo.assetEntity != null
                        ? ColorFiltered(
                            colorFilter: ColorFilter.matrix(preset.matrix.matrix),
                            child: Image(
                              image: AssetEntityImageProvider(
                                widget.photo.assetEntity!,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(100),
                              ),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)
                      .filmPresetName(preset.id, preset.name),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdjustTools() {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const ValueKey('tools'),
      controller: _toolsScroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      children: [
        _ToolButton(
          icon: Icons.exposure_rounded,
          label: l10n.adjExposure,
          isActive: _exposure != 0,
          onTap: () => setState(() => _activeTool = _AdjustTool.exposure),
        ),
        _ToolButton(
          icon: Icons.contrast_rounded,
          label: l10n.adjContrast,
          isActive: _contrast != 1.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.contrast),
        ),
        _ToolButton(
          icon: Icons.water_drop_outlined,
          label: l10n.adjSaturation,
          isActive: _saturation != 1.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.saturation),
        ),
        _ToolButton(
          icon: Icons.thermostat_rounded,
          label: l10n.adjTemperature,
          isActive: _temperature != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.temperature),
        ),
        _ToolButton(
          icon: Icons.invert_colors_rounded,
          label: l10n.adjTint,
          isActive: _tint != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.tint),
        ),
        _ToolButton(
          icon: Icons.gradient_rounded,
          label: l10n.adjFade,
          isActive: _fade != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.fade),
        ),
        _ToolButton(
          icon: Icons.grain_rounded,
          label: l10n.adjGrain,
          isActive: _grain != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.grain),
        ),
        _ToolButton(
          icon: Icons.vignette_rounded,
          label: l10n.adjVignette,
          isActive: _vignette != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.vignette),
        ),
        _ToolButton(
          icon: Icons.flare_rounded,
          label: l10n.adjLightLeak,
          isActive: _lightLeak != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.lightLeak),
        ),
        const SizedBox(width: 24),
        if (_hasAdjustments)
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _resetAdjustments();
            },
            icon: const Icon(Icons.settings_backup_restore_rounded,
                color: Colors.white54),
            tooltip: l10n.editorReset,
          ),
      ],
    );
  }

  Widget _buildSlider() {
    final l10n = AppLocalizations.of(context);
    double value = 0;
    double min = -1.0;
    double max = 1.0;
    String label = '';

    switch (_activeTool!) {
      case _AdjustTool.exposure:
        value = _exposure;
        label = l10n.adjExposure;
        break;
      case _AdjustTool.contrast:
        min = 0.5;
        max = 1.5;
        value = _contrast;
        label = l10n.adjContrast;
        break;
      case _AdjustTool.saturation:
        min = 0.0;
        max = 2.0;
        value = _saturation;
        label = l10n.adjSaturation;
        break;
      case _AdjustTool.temperature:
        value = _temperature;
        label = l10n.adjTemperature;
        break;
      case _AdjustTool.tint:
        value = _tint;
        label = l10n.adjTint;
        break;
      case _AdjustTool.fade:
        min = 0.0;
        max = 1.0;
        value = _fade;
        label = l10n.adjFade;
        break;
      case _AdjustTool.grain:
        min = 0.0;
        max = 1.0;
        value = _grain;
        label = l10n.adjGrain;
        break;
      case _AdjustTool.vignette:
        min = 0.0;
        max = 1.0;
        value = _vignette;
        label = l10n.adjVignette;
        break;
      case _AdjustTool.lightLeak:
        min = 0.0;
        max = 1.0;
        value = _lightLeak;
        label = l10n.adjLightLeak;
        break;
    }

    return Column(
      key: const ValueKey('slider'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _activeTool = null),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Icon(Icons.close_rounded, size: 20),
              ),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              TextButton(
                onPressed: () => setState(() => _activeTool = null),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Icon(Icons.check_rounded, size: 20),
              ),
            ],
          ),
        ),
        if (_activeTool == _AdjustTool.lightLeak) _buildLeakDirectionRow(),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (v) {
                setState(() {
                  switch (_activeTool!) {
                    case _AdjustTool.exposure:
                      _exposure = v;
                      break;
                    case _AdjustTool.contrast:
                      _contrast = v;
                      break;
                    case _AdjustTool.saturation:
                      _saturation = v;
                      break;
                    case _AdjustTool.temperature:
                      _temperature = v;
                      break;
                    case _AdjustTool.tint:
                      _tint = v;
                      break;
                    case _AdjustTool.fade:
                      _fade = v;
                      break;
                    case _AdjustTool.grain:
                      _grain = v;
                      break;
                    case _AdjustTool.vignette:
                      _vignette = v;
                      break;
                    case _AdjustTool.lightLeak:
                      _lightLeak = v;
                      break;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeakDirectionRow() {
    const dirs = <(IconData, Alignment)>[
      (Icons.north_west_rounded, Alignment.topLeft),
      (Icons.north_east_rounded, Alignment.topRight),
      (Icons.south_west_rounded, Alignment.bottomLeft),
      (Icons.south_east_rounded, Alignment.bottomRight),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (icon, align) in dirs)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _lightLeakDir = align);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _lightLeakDir == align
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _lightLeakDir == align
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: _lightLeakDir == align
                      ? Colors.white
                      : Colors.white54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.title,
    required this.isActive,
    required this.onTap,
    this.showDot = false,
  });

  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: showDot
                    ? (isActive ? Colors.white : Colors.white38)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white54,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
