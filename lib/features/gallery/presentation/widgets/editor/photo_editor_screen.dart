import 'dart:ui' as ui;
import 'package:photo_map/core/theme/app_icons.dart';

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
import 'local_adjust.dart';

enum _EditMode { presets, adjust, local }

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

enum _LocalTool {
  size,
  feather,
  brushSize,
  exposure,
  shadows,
  highlights,
  warmth,
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

  // ── Local adjust state ──
  List<LocalMask> _masks = const [];
  int? _selectedMaskId;
  int _nextMaskId = 1;
  _LocalTool? _activeLocalTool;
  bool _showMaskOverlay = true;
  double _brushSize = 0.06; // fraction of shortest side
  // Decoded preview frame; local masks re-draw the image per mask, which
  // needs a ui.Image (the Image widget alone can't be re-composited).
  ui.Image? _previewImage;
  // In-progress brush stroke (normalized points), committed on pan end.
  List<Offset>? _activeStrokePoints;
  bool _dragLinearIsStart = true;
  final GlobalKey _viewportKey = GlobalKey();

  // Persistent so the horizontal tool strip keeps its scroll offset when the
  // slider opens/closes (the AnimatedSwitcher otherwise rebuilds it at 0).
  final ScrollController _toolsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPreviewImage();
  }

  @override
  void dispose() {
    _toolsScroll.dispose();
    _previewImage?.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewImage() async {
    final asset = widget.photo.assetEntity;
    if (asset == null) return;
    try {
      final data =
          await asset.thumbnailDataWithSize(const ThumbnailSize(2048, 2048));
      if (data == null) return;
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _previewImage = frame.image);
    } catch (e) {
      debugPrint('PhotoEditor: preview decode failed: $e');
    }
  }

  LocalMask? get _selectedMask {
    if (_selectedMaskId == null) return null;
    for (final m in _masks) {
      if (m.id == _selectedMaskId) return m;
    }
    return null;
  }

  void _updateSelectedMask(LocalMask updated) {
    setState(() {
      _masks = [
        for (final m in _masks) m.id == updated.id ? updated : m,
      ];
    });
  }

  void _addMask(LocalMaskType type) {
    HapticFeedback.selectionClick();
    final mask = LocalMask(id: _nextMaskId++, type: type);
    setState(() {
      _masks = [..._masks, mask];
      _selectedMaskId = mask.id;
      _activeLocalTool = null;
    });
  }

  void _deleteSelectedMask() {
    if (_selectedMaskId == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _masks = _masks.where((m) => m.id != _selectedMaskId).toList();
      _selectedMaskId = _masks.isEmpty ? null : _masks.last.id;
      _activeLocalTool = null;
    });
  }

  bool get _maskEditingActive =>
      _mode == _EditMode.local && _selectedMask != null;

  // Hide the red overlay while a tonal slider is open so the user sees the
  // actual effect; keep it for geometry tools where coverage matters.
  bool get _overlayVisible {
    if (!_maskEditingActive || !_showMaskOverlay || _showOriginal) {
      return false;
    }
    return _activeLocalTool == null ||
        _activeLocalTool == _LocalTool.size ||
        _activeLocalTool == _LocalTool.feather ||
        _activeLocalTool == _LocalTool.brushSize;
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

      // Bake the same pipeline the preview shows: colour matrix first, local
      // masks over the graded base, then the film overlays on top, all at
      // full source resolution.
      final baseMatrix = _combinedMatrix;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, rect);
      canvas.drawImage(
        source,
        Offset.zero,
        Paint()
          ..colorFilter = ColorFilter.matrix(baseMatrix.matrix)
          ..filterQuality = FilterQuality.high,
      );
      paintLocalMasks(canvas, rect, source, _masks, baseMatrix);
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
            switch (_mode) {
              _EditMode.presets => l10n.editorPresets,
              _EditMode.adjust => l10n.editorAdjust,
              _EditMode.local => l10n.editorLocal,
            },
            style: const TextStyle(
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
    final editing = _maskEditingActive;
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _showOriginal = true),
      onLongPressEnd: (_) => setState(() => _showOriginal = false),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        // While a mask is being edited single-finger drags belong to the
        // mask gestures, not pan/zoom.
        panEnabled: !editing,
        scaleEnabled: !editing,
        child: Center(
          child: widget.photo.assetEntity != null
              ? GestureDetector(
                  onPanStart: editing ? _onMaskPanStart : null,
                  onPanUpdate: editing ? _onMaskPanUpdate : null,
                  onPanEnd: editing ? _onMaskPanEnd : null,
                  child: CustomPaint(
                    key: _viewportKey,
                    // foregroundPainter paints over exactly the image's
                    // rendered box, so grain/vignette/leak align with the
                    // photo (not the letterbox bars).
                    foregroundPainter: _showOriginal
                        ? null
                        : FilmOverlayPainter(
                            vignette: _vignette,
                            lightLeak: _lightLeak,
                            grain: _grain,
                            lightLeakDirection: _lightLeakDir,
                          ),
                    child: CustomPaint(
                      foregroundPainter:
                          (_previewImage != null && !_showOriginal)
                              ? LocalMasksPainter(
                                  image: _previewImage!,
                                  masks: _masks,
                                  baseMatrix: _combinedMatrix,
                                  overlayMask:
                                      _overlayVisible ? _displayedMask : null,
                                )
                              : null,
                      child: ColorFiltered(
                        colorFilter:
                            ColorFilter.matrix(_combinedMatrix.matrix),
                        child: Image(
                          image: AssetEntityImageProvider(
                            widget.photo.assetEntity!,
                            isOriginal: true,
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
  }

  /// The selected mask with the in-progress brush stroke merged in, so the
  /// red overlay tracks the finger while painting.
  LocalMask? get _displayedMask {
    final mask = _selectedMask;
    if (mask == null) return null;
    final points = _activeStrokePoints;
    if (mask.type != LocalMaskType.brush || points == null || points.isEmpty) {
      return mask;
    }
    return mask.copyWith(strokes: [
      ...mask.strokes,
      BrushStroke(points: List.of(points), radius: _brushSize),
    ]);
  }

  // ── Mask gestures (normalized image-space coordinates) ──

  Offset? _normalize(Offset local) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return null;
    return Offset(
      (local.dx / box.size.width).clamp(0.0, 1.0),
      (local.dy / box.size.height).clamp(0.0, 1.0),
    );
  }

  void _onMaskPanStart(DragStartDetails details) {
    final mask = _selectedMask;
    final p = _normalize(details.localPosition);
    if (mask == null || p == null) return;
    switch (mask.type) {
      case LocalMaskType.radial:
        _updateSelectedMask(mask.copyWith(center: p));
        break;
      case LocalMaskType.linear:
        // Grab whichever endpoint is closer and drag it.
        _dragLinearIsStart = (p - mask.linearStart).distance <=
            (p - mask.linearEnd).distance;
        _updateSelectedMask(_dragLinearIsStart
            ? mask.copyWith(linearStart: p)
            : mask.copyWith(linearEnd: p));
        break;
      case LocalMaskType.brush:
        setState(() => _activeStrokePoints = [p]);
        break;
    }
  }

  void _onMaskPanUpdate(DragUpdateDetails details) {
    final mask = _selectedMask;
    final p = _normalize(details.localPosition);
    if (mask == null || p == null) return;
    switch (mask.type) {
      case LocalMaskType.radial:
        _updateSelectedMask(mask.copyWith(center: p));
        break;
      case LocalMaskType.linear:
        _updateSelectedMask(_dragLinearIsStart
            ? mask.copyWith(linearStart: p)
            : mask.copyWith(linearEnd: p));
        break;
      case LocalMaskType.brush:
        setState(() => _activeStrokePoints = [...?_activeStrokePoints, p]);
        break;
    }
  }

  void _onMaskPanEnd(DragEndDetails details) {
    final mask = _selectedMask;
    final points = _activeStrokePoints;
    if (mask != null &&
        mask.type == LocalMaskType.brush &&
        points != null &&
        points.isNotEmpty) {
      _updateSelectedMask(mask.copyWith(strokes: [
        ...mask.strokes,
        BrushStroke(points: points, radius: _brushSize),
      ]));
    }
    setState(() => _activeStrokePoints = null);
  }

  Widget _buildBottomSection() {
    final l10n = AppLocalizations.of(context);
    final Widget middle = switch (_mode) {
      _EditMode.presets => _buildPresetsList(),
      _EditMode.adjust =>
        _activeTool != null ? _buildSlider() : _buildAdjustTools(),
      _EditMode.local =>
        _activeLocalTool != null ? _buildLocalSlider() : _buildLocalControls(),
    };
    final tabsVisible = _activeTool == null && _activeLocalTool == null;
    return Container(
      height: 190,
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
                child: middle,
              ),
            ),
          ),
          if (tabsVisible)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BottomTab(
                    title: l10n.editorPresets.toUpperCase(),
                    isActive: _mode == _EditMode.presets,
                    onTap: () => setState(() => _mode = _EditMode.presets),
                  ),
                  _BottomTab(
                    title: l10n.editorAdjust.toUpperCase(),
                    isActive: _mode == _EditMode.adjust,
                    onTap: () => setState(() => _mode = _EditMode.adjust),
                    showDot: _hasAdjustments,
                  ),
                  _BottomTab(
                    title: l10n.editorLocal.toUpperCase(),
                    isActive: _mode == _EditMode.local,
                    onTap: () => setState(() => _mode = _EditMode.local),
                    showDot: _masks.isNotEmpty,
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
          icon: AppIcons.exposure_rounded,
          label: l10n.adjExposure,
          isActive: _exposure != 0,
          onTap: () => setState(() => _activeTool = _AdjustTool.exposure),
        ),
        _ToolButton(
          icon: AppIcons.contrast_rounded,
          label: l10n.adjContrast,
          isActive: _contrast != 1.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.contrast),
        ),
        _ToolButton(
          icon: AppIcons.water_drop_outlined,
          label: l10n.adjSaturation,
          isActive: _saturation != 1.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.saturation),
        ),
        _ToolButton(
          icon: AppIcons.thermostat_rounded,
          label: l10n.adjTemperature,
          isActive: _temperature != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.temperature),
        ),
        _ToolButton(
          icon: AppIcons.invert_colors_rounded,
          label: l10n.adjTint,
          isActive: _tint != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.tint),
        ),
        _ToolButton(
          icon: AppIcons.gradient_rounded,
          label: l10n.adjFade,
          isActive: _fade != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.fade),
        ),
        _ToolButton(
          icon: AppIcons.grain_rounded,
          label: l10n.adjGrain,
          isActive: _grain != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.grain),
        ),
        _ToolButton(
          icon: AppIcons.vignette_rounded,
          label: l10n.adjVignette,
          isActive: _vignette != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.vignette),
        ),
        _ToolButton(
          icon: AppIcons.flare_rounded,
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
            icon: const Icon(AppIcons.settings_backup_restore_rounded,
                color: Colors.white54),
            tooltip: l10n.editorReset,
          ),
      ],
    );
  }

  // ── Local adjust UI ──

  Widget _buildLocalControls() {
    final l10n = AppLocalizations.of(context);
    final mask = _selectedMask;
    if (_masks.isEmpty) {
      return Column(
        key: const ValueKey('local-empty'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.localAddMaskHint,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ToolButton(
                icon: AppIcons.mask_radial,
                label: l10n.localMaskRadial,
                isActive: false,
                onTap: () => _addMask(LocalMaskType.radial),
              ),
              _ToolButton(
                icon: AppIcons.mask_linear,
                label: l10n.localMaskLinear,
                isActive: false,
                onTap: () => _addMask(LocalMaskType.linear),
              ),
              _ToolButton(
                icon: AppIcons.mask_brush,
                label: l10n.localMaskBrush,
                isActive: false,
                onTap: () => _addMask(LocalMaskType.brush),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('local-controls'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 40, child: _buildMaskChips()),
        Expanded(
          child: mask == null ? const SizedBox() : _buildLocalTools(mask),
        ),
      ],
    );
  }

  Widget _buildMaskChips() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      children: [
        for (final (i, mask) in _masks.indexed)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedMaskId = mask.id);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: mask.id == _selectedMaskId
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: mask.id == _selectedMaskId
                      ? Colors.white
                      : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    switch (mask.type) {
                      LocalMaskType.radial => AppIcons.mask_radial,
                      LocalMaskType.linear => AppIcons.mask_linear,
                      LocalMaskType.brush => AppIcons.mask_brush,
                    },
                    size: 14,
                    color: mask.id == _selectedMaskId
                        ? Colors.white
                        : Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: mask.id == _selectedMaskId
                          ? Colors.white
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final type in LocalMaskType.values)
          GestureDetector(
            onTap: () => _addMask(type),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.add, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Icon(
                    switch (type) {
                      LocalMaskType.radial => AppIcons.mask_radial,
                      LocalMaskType.linear => AppIcons.mask_linear,
                      LocalMaskType.brush => AppIcons.mask_brush,
                    },
                    size: 14,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocalTools(LocalMask mask) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        if (mask.type == LocalMaskType.radial) ...[
          _ToolButton(
            icon: AppIcons.mask_size,
            label: l10n.localSize,
            isActive: false,
            onTap: () => setState(() => _activeLocalTool = _LocalTool.size),
          ),
          _ToolButton(
            icon: AppIcons.mask_feather,
            label: l10n.localFeather,
            isActive: false,
            onTap: () => setState(() => _activeLocalTool = _LocalTool.feather),
          ),
        ],
        if (mask.type == LocalMaskType.brush)
          _ToolButton(
            icon: AppIcons.mask_size,
            label: l10n.localBrushSize,
            isActive: false,
            onTap: () =>
                setState(() => _activeLocalTool = _LocalTool.brushSize),
          ),
        _ToolButton(
          icon: AppIcons.exposure_rounded,
          label: l10n.adjExposure,
          isActive: mask.exposure != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.exposure),
        ),
        _ToolButton(
          icon: AppIcons.adj_shadows,
          label: l10n.adjShadows,
          isActive: mask.shadows != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.shadows),
        ),
        _ToolButton(
          icon: AppIcons.adj_highlights,
          label: l10n.adjHighlights,
          isActive: mask.highlights != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.highlights),
        ),
        _ToolButton(
          icon: AppIcons.thermostat_rounded,
          label: l10n.adjWarmth,
          isActive: mask.warmth != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.warmth),
        ),
        _ToolButton(
          icon: _showMaskOverlay ? AppIcons.mask_show : AppIcons.mask_hide,
          label: l10n.localShowMask,
          isActive: _showMaskOverlay,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showMaskOverlay = !_showMaskOverlay);
          },
        ),
        _ToolButton(
          icon: AppIcons.delete_outline,
          label: l10n.commonDelete,
          isActive: false,
          onTap: _deleteSelectedMask,
        ),
      ],
    );
  }

  Widget _buildLocalSlider() {
    final l10n = AppLocalizations.of(context);
    final mask = _selectedMask;
    final tool = _activeLocalTool;
    if (mask == null || tool == null) return const SizedBox();

    double value;
    double min = -1.0;
    double max = 1.0;
    String label;
    switch (tool) {
      case _LocalTool.size:
        min = 0.05;
        max = 0.6;
        value = mask.radius;
        label = l10n.localSize;
        break;
      case _LocalTool.feather:
        min = 0.0;
        max = 1.0;
        value = mask.feather;
        label = l10n.localFeather;
        break;
      case _LocalTool.brushSize:
        min = 0.02;
        max = 0.15;
        value = _brushSize;
        label = l10n.localBrushSize;
        break;
      case _LocalTool.exposure:
        value = mask.exposure;
        label = l10n.adjExposure;
        break;
      case _LocalTool.shadows:
        value = mask.shadows;
        label = l10n.adjShadows;
        break;
      case _LocalTool.highlights:
        value = mask.highlights;
        label = l10n.adjHighlights;
        break;
      case _LocalTool.warmth:
        value = mask.warmth;
        label = l10n.adjWarmth;
        break;
    }

    return Column(
      key: const ValueKey('local-slider'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _activeLocalTool = null),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Icon(AppIcons.close_rounded, size: 20),
              ),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              TextButton(
                onPressed: () => setState(() => _activeLocalTool = null),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Icon(AppIcons.check_rounded, size: 20),
              ),
            ],
          ),
        ),
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
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: (v) {
                switch (tool) {
                  case _LocalTool.size:
                    _updateSelectedMask(mask.copyWith(radius: v));
                    break;
                  case _LocalTool.feather:
                    _updateSelectedMask(mask.copyWith(feather: v));
                    break;
                  case _LocalTool.brushSize:
                    setState(() => _brushSize = v);
                    break;
                  case _LocalTool.exposure:
                    _updateSelectedMask(mask.copyWith(exposure: v));
                    break;
                  case _LocalTool.shadows:
                    _updateSelectedMask(mask.copyWith(shadows: v));
                    break;
                  case _LocalTool.highlights:
                    _updateSelectedMask(mask.copyWith(highlights: v));
                    break;
                  case _LocalTool.warmth:
                    _updateSelectedMask(mask.copyWith(warmth: v));
                    break;
                }
              },
            ),
          ),
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
                child: const Icon(AppIcons.close_rounded, size: 20),
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
                child: const Icon(AppIcons.check_rounded, size: 20),
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
      (AppIcons.north_west_rounded, Alignment.topLeft),
      (AppIcons.north_east_rounded, Alignment.topRight),
      (AppIcons.south_west_rounded, Alignment.bottomLeft),
      (AppIcons.south_east_rounded, Alignment.bottomRight),
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
