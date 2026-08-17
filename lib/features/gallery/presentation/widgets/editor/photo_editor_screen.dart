import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:photo_map/core/theme/app_icons.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/common_widgets/app_snack.dart';
import 'package:photo_map/common_widgets/asset_thumb.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../providers/gallery_notifier.dart';
import '../../../utils/color_matrix_utils.dart';
import 'film_effects.dart';
import 'heal.dart';
import 'local_adjust.dart';
import 'package:photo_map/common_widgets/asset_thumbnail_provider.dart';

enum _EditMode { presets, adjust, local, heal }

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
  feather,
  brushSize,
  brushFeather,
  brushFlow,
  exposure,
  contrast,
  shadows,
  highlights,
  saturation,
  warmth,
  tint,
  amount,
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
  double _brushFeather = 0.6; // edge softness as a fraction of the radius
  double _brushFlow = 1.0; // coverage laid down per stroke
  bool _brushErase = false; // Lightroom's Add / Erase pair
  // Decoded preview frame; local masks re-draw the image per mask, which
  // needs a ui.Image (the Image widget alone can't be re-composited).
  ui.Image? _previewImage;
  // In-progress brush stroke (normalized points), committed on pan end.
  List<Offset>? _activeStrokePoints;
  // Which handle the current drag grabbed, plus the geometry it started from —
  // every update resolves against the start state so a drag can never feed its
  // own result back and drift.
  MaskHandle? _dragHandle;
  LocalMask? _dragStartMask;
  Offset? _dragStartPx;
  // Raw-pointer bookkeeping: how many fingers are on the photo, where the
  // first one landed, and whether it has travelled far enough to be a drag.
  int _pointers = 0;
  Offset? _downPx;
  bool _editDrag = false;
  final GlobalKey _viewportKey = GlobalKey();

  // ── Heal / remove state ──
  List<HealStroke> _healStrokes = const [];
  List<Offset>? _activeHealPoints;
  double _healBrush = 0.05;
  bool _healing = false;
  /// [_previewImage] with every heal stroke applied — what the viewport and the
  /// mask painter draw from once anything has been removed.
  ui.Image? _healedPreview;

  /// Source of truth for everything painted: the repaired frame when there is
  /// one, the raw decode otherwise.
  ui.Image? get _baseImage => _healedPreview ?? _previewImage;

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
    _healedPreview?.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewImage() async {
    final asset = widget.photo.assetEntity;
    if (asset == null) return;
    try {
      // Sharp option, not thumbnailDataWithSize: that one asks PhotoKit
      // opportunistically and comes back with the degraded pass, which is what
      // the editor would then have been grading — and showing as the result.
      final data = await AssetThumbnailProvider.sharpBytes(
        asset,
        const ThumbnailSize(2048, 2048),
      );
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

  // ── Heal / remove ──

  /// Re-runs every heal stroke against the pristine decode. Rebuilding from
  /// scratch (rather than patching the last result) is what makes undo cheap
  /// and keeps repeated strokes from compounding artefacts.
  Future<void> _rebuildHeal() async {
    final source = _previewImage;
    if (source == null) return;
    if (_healStrokes.isEmpty) {
      final stale = _healedPreview;
      setState(() => _healedPreview = null);
      stale?.dispose();
      return;
    }

    setState(() => _healing = true);
    try {
      final strokes = List.of(_healStrokes);
      final result = await applyHeal(source, strokes);
      if (!mounted) {
        if (!identical(result, source)) result.dispose();
        return;
      }
      // A newer stroke may have landed while this one was in the isolate.
      if (!listEquals(strokes, _healStrokes)) {
        if (!identical(result, source)) result.dispose();
        return;
      }
      final stale = _healedPreview;
      setState(() => _healedPreview = identical(result, source) ? null : result);
      stale?.dispose();
    } catch (e) {
      debugPrint('PhotoEditor: heal failed: $e');
    } finally {
      if (mounted) setState(() => _healing = false);
    }
  }

  void _undoHeal() {
    if (_healStrokes.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _healStrokes = _healStrokes.sublist(0, _healStrokes.length - 1);
    });
    _rebuildHeal();
  }

  void _clearHeal() {
    if (_healStrokes.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _healStrokes = const []);
    _rebuildHeal();
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
    // Radial masks start as an ellipse, like Lightroom's: on a perfect circle
    // the rotate handle moves but nothing on screen changes, which reads as a
    // broken control.
    final mask = type == LocalMaskType.radial
        ? LocalMask(id: _nextMaskId++, type: type, radius: 0.32, radiusY: 0.22)
        : LocalMask(id: _nextMaskId++, type: type);
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
        _activeLocalTool == _LocalTool.feather ||
        _activeLocalTool == _LocalTool.brushSize ||
        _activeLocalTool == _LocalTool.brushFeather ||
        _activeLocalTool == _LocalTool.brushFlow ||
        _activeLocalTool == _LocalTool.amount;
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
      final decoded = frame.image;

      // Removals run against the full-resolution original — the strokes are
      // normalized, so the repair lands exactly where the preview showed it.
      final source = await applyHeal(decoded, _healStrokes);
      final healedSeparately = !identical(source, decoded);

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
      picture.dispose();
      out.dispose();
      if (healedSeparately) source.dispose();
      decoded.dispose();
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
              _EditMode.heal => l10n.editorHeal,
            },
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Undo lives up here rather than in the tool strip: it applies to
              // whatever the current mode last did, and it stays reachable
              // while a slider panel has taken over the strip.
              IconButton(
                onPressed: _canUndo ? _undo : null,
                icon: const Icon(AppIcons.settings_backup_restore_rounded,
                    size: 20),
                color: Colors.white,
                disabledColor: Colors.white24,
                visualDensity: VisualDensity.compact,
                tooltip: l10n.editorUndo,
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
        ],
      ),
    );
  }

  Widget _buildImageViewport() {
    final healing = _mode == _EditMode.heal;
    final editing = _maskEditingActive || healing;
    final base = _baseImage;
    return GestureDetector(
      // A slow mask drag must not trip the compare-original long press.
      onLongPressStart: (_) {
        if (_editDrag) return;
        setState(() => _showOriginal = true);
      },
      onLongPressEnd: (_) => setState(() => _showOriginal = false),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        // Only the one-finger pan is handed to the editing tools; pinch always
        // belongs to the viewer. The tools listen to raw pointer events (see
        // [_onPointerDown]) precisely so they never enter the gesture arena and
        // steal the second finger from the scale recognizer.
        panEnabled: !editing,
        scaleEnabled: true,
        child: Center(
          child: widget.photo.assetEntity != null
              ? Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: (_) => _cancelEdit(),
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
                      foregroundPainter: (base != null && !_showOriginal)
                          ? LocalMasksPainter(
                              image: base,
                              masks: _masks,
                              baseMatrix: _combinedMatrix,
                              overlayMask:
                                  _overlayVisible ? _displayedMask : null,
                              healStroke: _activeHealPoints,
                              healRadius: _healBrush,
                            )
                          : null,
                      child: ColorFiltered(
                        colorFilter:
                            ColorFilter.matrix(_combinedMatrix.matrix),
                        // Once anything has been healed the repaired frame is
                        // the only correct source, so paint the decoded image
                        // rather than the asset provider.
                        child: base != null
                            ? RawImage(
                                image: base,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              )
                            : Image(
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
      BrushStroke(
        points: List.of(points),
        radius: _brushSize,
        erase: _brushErase,
        feather: _brushFeather,
        flow: _brushFlow,
      ),
    ]);
  }

  // ── Mask gestures (normalized image-space coordinates) ──

  Offset? _normalize(Offset local) {
    final rect = _viewportRect;
    if (rect == null) return null;
    return Offset(
      (local.dx / rect.width).clamp(0.0, 1.0),
      (local.dy / rect.height).clamp(0.0, 1.0),
    );
  }

  /// The painted image box in its own local pixels — handle hit-testing and
  /// geometry drags all work here, then convert to normalized space on write.
  Rect? get _viewportRect {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return null;
    return Offset.zero & box.size;
  }

  // ── Raw pointer routing ──
  //
  // Editing runs on raw pointer events rather than a GestureDetector: a pan
  // recognizer here would win the gesture arena against InteractiveViewer's
  // scale recognizer and swallow the second finger, killing pinch-zoom the
  // moment a mask was selected. A Listener never competes, so the viewer keeps
  // every multi-touch gesture and we simply ignore anything past one finger.

  /// Distance a finger must travel before a touch counts as a drag rather than
  /// a tap. Tighter than [kTouchSlop] — mask work is precise.
  static const double _kDragSlop = 10.0;

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    if (_pointers > 1) {
      // Second finger down: the viewer is about to pinch, so give back
      // whatever this drag had already changed.
      _cancelEdit();
      return;
    }
    _downPx = event.localPosition;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointers != 1) return;
    final down = _downPx;
    if (down == null) return;
    if (!_editDrag) {
      if ((event.localPosition - down).distance < _kDragSlop) return;
      if (!_beginEdit(down)) {
        _downPx = null; // Nothing here to drag — let the touch be a tap.
        return;
      }
      _editDrag = true;
    }
    _updateEdit(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers = (_pointers - 1).clamp(0, 10);
    if (_editDrag) {
      _endEdit();
      return;
    }
    final down = _downPx;
    _downPx = null;
    if (down != null && _pointers == 0 && _mode == _EditMode.local) {
      _onViewportTap(down);
    }
  }

  /// Starts a drag at [p]; false when there is nothing to drag there.
  bool _beginEdit(Offset p) {
    if (_mode == _EditMode.heal) {
      final n = _normalize(p);
      if (n == null) return false;
      setState(() => _activeHealPoints = [n]);
      return true;
    }
    final mask = _selectedMask;
    final rect = _viewportRect;
    if (mask == null || rect == null) return false;

    if (mask.type == LocalMaskType.brush) {
      final n = _normalize(p);
      if (n == null) return false;
      setState(() => _activeStrokePoints = [n]);
      return true;
    }

    // Radial and linear masks are manipulated straight on the photo: whichever
    // handle the finger landed on decides whether this drag moves, resizes or
    // rotates.
    _dragStartMask = mask;
    _dragStartPx = p;
    _dragHandle = mask.type == LocalMaskType.radial
        ? radialHandleAt(mask, p, rect)
        : linearHandleAt(mask, p, rect);
    HapticFeedback.selectionClick();
    return true;
  }

  void _updateEdit(Offset p) {
    if (_mode == _EditMode.heal) {
      final n = _normalize(p);
      if (n == null) return;
      setState(() => _activeHealPoints = [...?_activeHealPoints, n]);
      return;
    }
    final mask = _selectedMask;
    final rect = _viewportRect;
    if (mask == null || rect == null) return;

    if (mask.type == LocalMaskType.brush) {
      final n = _normalize(p);
      if (n == null) return;
      setState(() => _activeStrokePoints = [...?_activeStrokePoints, n]);
      return;
    }

    final start = _dragStartMask;
    final from = _dragStartPx;
    final handle = _dragHandle;
    if (start == null || from == null || handle == null) return;
    _updateSelectedMask(start.type == LocalMaskType.radial
        ? _dragRadial(start, handle, rect, from, p)
        : _dragLinear(start, handle, rect, from, p));
  }

  void _endEdit() {
    _editDrag = false;
    _downPx = null;

    if (_mode == _EditMode.heal) {
      final points = _activeHealPoints;
      setState(() => _activeHealPoints = null);
      if (points == null || points.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() {
        _healStrokes = [
          ..._healStrokes,
          HealStroke(points: points, radius: _healBrush),
        ];
      });
      _rebuildHeal();
      return;
    }

    final mask = _selectedMask;
    final points = _activeStrokePoints;
    if (mask != null &&
        mask.type == LocalMaskType.brush &&
        points != null &&
        points.isNotEmpty) {
      _updateSelectedMask(mask.copyWith(strokes: [
        ...mask.strokes,
        BrushStroke(
          points: points,
          radius: _brushSize,
          erase: _brushErase,
          feather: _brushFeather,
          flow: _brushFlow,
        ),
      ]));
    }
    _dragHandle = null;
    _dragStartMask = null;
    _dragStartPx = null;
    setState(() => _activeStrokePoints = null);
  }

  /// Drops an in-progress drag and rolls the mask back to where it started.
  void _cancelEdit() {
    _downPx = null;
    if (!_editDrag) return;
    _editDrag = false;
    final start = _dragStartMask;
    if (start != null) _updateSelectedMask(start);
    _dragHandle = null;
    _dragStartMask = null;
    _dragStartPx = null;
    setState(() {
      _activeStrokePoints = null;
      _activeHealPoints = null;
    });
  }

  /// Tapping the photo picks the mask under the finger, so switching between
  /// masks never means going back down to the chip row. Topmost (last painted)
  /// wins; with a brush mask already under the finger the tap dabs a dot
  /// instead, the way Lightroom's brush does.
  void _onViewportTap(Offset p) {
    final rect = _viewportRect;
    if (rect == null) return;

    for (final mask in _masks.reversed) {
      if (!maskContains(mask, p, rect)) continue;
      if (mask.id == _selectedMaskId) break;
      HapticFeedback.selectionClick();
      setState(() {
        _selectedMaskId = mask.id;
        _activeLocalTool = null;
      });
      return;
    }

    final selected = _selectedMask;
    if (selected == null || selected.type != LocalMaskType.brush) return;
    final n = _normalize(p);
    if (n == null) return;
    HapticFeedback.selectionClick();
    _updateSelectedMask(selected.copyWith(strokes: [
      ...selected.strokes,
      BrushStroke(
        points: [n],
        radius: _brushSize,
        erase: _brushErase,
        feather: _brushFeather,
        flow: _brushFlow,
      ),
    ]));
  }


  /// Normalized point for a viewport pixel. Masks may sit slightly off-frame
  /// (a gradient anchored past the edge is useful), hence the loose clamp.
  static Offset _toNorm(Offset px, Rect rect) => Offset(
        (px.dx / rect.width).clamp(-0.5, 1.5),
        (px.dy / rect.height).clamp(-0.5, 1.5),
      );

  LocalMask _dragRadial(
    LocalMask m,
    MaskHandle handle,
    Rect rect,
    Offset from,
    Offset to,
  ) {
    final h = RadialHandles(m, rect);
    final short = rect.shortestSide;
    switch (handle) {
      case MaskHandle.rotate:
        final v = to - h.center;
        if (v.distance < 4) return m;
        // The handle rides one of the mask's axes; [rotateTurn] says which.
        return m.copyWith(angle: math.atan2(v.dy, v.dx) - h.rotateTurn);
      case MaskHandle.resizeX:
        return m.copyWith(
          radius: (h.along(to, h.axisX).abs() / short).clamp(0.02, 2.0),
        );
      case MaskHandle.resizeY:
        return m.copyWith(
          radiusY: (h.along(to, h.axisY).abs() / short).clamp(0.02, 2.0),
        );
      case MaskHandle.resize:
        // edgeT is 1.0 on the ring, so it doubles as the scale factor.
        final t = h.edgeT(to).clamp(0.05, 8.0);
        return m.copyWith(
          radius: (m.radius * t).clamp(0.02, 2.0),
          radiusY: (m.radiusY * t).clamp(0.02, 2.0),
        );
      case MaskHandle.feather:
        // The inner ellipse sits at (1 - feather) of the outer one.
        return m.copyWith(feather: (1.0 - h.edgeT(to)).clamp(0.0, 0.95));
      case MaskHandle.move:
      case MaskHandle.start:
      case MaskHandle.end:
        final d = to - from;
        return m.copyWith(
          center: _toNorm(h.center + d, rect),
        );
    }
  }

  LocalMask _dragLinear(
    LocalMask m,
    MaskHandle handle,
    Rect rect,
    Offset from,
    Offset to,
  ) {
    final h = LinearHandles(m, rect);
    switch (handle) {
      case MaskHandle.start:
        return m.copyWith(linearStart: _toNorm(to, rect));
      case MaskHandle.end:
        return m.copyWith(linearEnd: _toNorm(to, rect));
      case MaskHandle.rotate:
        final v = to - h.mid;
        if (v.distance < 4) return m;
        // The handle rides the normal, so the axis is a quarter turn behind it
        // — the other way round when it had to flip to stay on the photo.
        final a = math.atan2(v.dy, v.dx) - h.rotateTurn;
        final dir = Offset(math.cos(a), math.sin(a));
        final half = (h.end - h.start).distance / 2;
        return m.copyWith(
          linearStart: _toNorm(h.mid - dir * half, rect),
          linearEnd: _toNorm(h.mid + dir * half, rect),
        );
      case MaskHandle.move:
      case MaskHandle.resize:
      case MaskHandle.resizeX:
      case MaskHandle.resizeY:
      case MaskHandle.feather:
        final d = to - from;
        return m.copyWith(
          linearStart: _toNorm(h.start + d, rect),
          linearEnd: _toNorm(h.end + d, rect),
        );
    }
  }

  /// Whether the current mode has a step to take back. Presets and the global
  /// adjust sliders are already reversible by dragging, so only the stroke
  /// tools take part.
  bool get _canUndo {
    if (_mode == _EditMode.heal) return _healStrokes.isNotEmpty;
    if (_mode != _EditMode.local) return false;
    final mask = _selectedMask;
    return mask != null &&
        mask.type == LocalMaskType.brush &&
        mask.strokes.isNotEmpty;
  }

  void _undo() {
    if (_mode == _EditMode.heal) {
      _undoHeal();
      return;
    }
    _undoStroke();
  }

  /// Drops the most recent brush stroke on the selected mask.
  void _undoStroke() {
    final mask = _selectedMask;
    if (mask == null || mask.strokes.isEmpty) return;
    HapticFeedback.lightImpact();
    _updateSelectedMask(
      mask.copyWith(strokes: mask.strokes.sublist(0, mask.strokes.length - 1)),
    );
  }

  Widget _buildBottomSection() {
    final l10n = AppLocalizations.of(context);
    final Widget middle = switch (_mode) {
      _EditMode.presets => _buildPresetsList(),
      _EditMode.adjust =>
        _activeTool != null ? _buildSlider() : _buildAdjustTools(),
      _EditMode.local =>
        _activeLocalTool != null ? _buildLocalSlider() : _buildLocalControls(),
      _EditMode.heal => _buildHealControls(),
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
                  _BottomTab(
                    title: l10n.editorHeal.toUpperCase(),
                    isActive: _mode == _EditMode.heal,
                    onTap: () => setState(() => _mode = _EditMode.heal),
                    showDot: _healStrokes.isNotEmpty,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Heal / remove UI ──

  Widget _buildHealControls() {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('heal'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 20,
          child: _healing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.healWorking,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                )
              : Text(
                  _healStrokes.isEmpty ? l10n.healHint : l10n.healCount(_healStrokes.length),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
        ),
        const SizedBox(height: 8),
        // Brush size lives inline — it is the one control you reach for
        // constantly while removing things.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(AppIcons.mask_size, size: 14, color: Colors.white38),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.1),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _healBrush,
                    min: 0.015,
                    max: 0.12,
                    onChanged: (v) => setState(() => _healBrush = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        _ToolButton(
          icon: AppIcons.delete_outline,
          label: l10n.editorReset,
          isActive: false,
          onTap: _clearHeal,
        ),
      ],
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
                        ? AssetThumb(
                            asset: widget.photo.assetEntity!,
                            maxPixels: 400,
                            colorFilter:
                                ColorFilter.matrix(preset.matrix.matrix),
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

  static IconData _maskIcon(LocalMaskType type) => switch (type) {
        LocalMaskType.radial => AppIcons.mask_radial,
        LocalMaskType.linear => AppIcons.mask_linear,
        LocalMaskType.brush => AppIcons.mask_brush,
      };

  static String _maskName(AppLocalizations l10n, LocalMaskType type) =>
      switch (type) {
        LocalMaskType.radial => l10n.localMaskRadial,
        LocalMaskType.linear => l10n.localMaskLinear,
        LocalMaskType.brush => l10n.localMaskBrush,
      };

  /// The mask row: masks that exist on the left, buttons that create one on
  /// the right. The two groups used to look identical — same pill, same icon —
  /// so it was guesswork which one added and which one selected. Now the
  /// existing masks are named and numbered, the add buttons are labelled
  /// `+ type`, and a divider keeps them apart.
  Widget _buildMaskChips() {
    final l10n = AppLocalizations.of(context);
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      children: [
        for (final (i, mask) in _masks.indexed)
          _MaskChip(
            icon: _maskIcon(mask.type),
            label: '${_maskName(l10n, mask.type)} ${i + 1}',
            selected: mask.id == _selectedMaskId,
            // A quiet dot marks masks that actually change something, so an
            // untouched mask is obvious at a glance.
            showDot: mask.hasEffect,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedMaskId = mask.id;
                _activeLocalTool = null;
              });
            },
          ),
        Container(
          width: 1,
          height: 18,
          margin: const EdgeInsets.fromLTRB(4, 7, 12, 7),
          color: Colors.white24,
        ),
        for (final type in LocalMaskType.values)
          _MaskChip(
            icon: _maskIcon(type),
            label: _maskName(l10n, type),
            selected: false,
            isAdd: true,
            onTap: () => _addMask(type),
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
          // Size and rotation live on the canvas handles now — only feather has
          // no direct gesture.
          _ToolButton(
            icon: AppIcons.mask_feather,
            label: l10n.localFeather,
            isActive: false,
            onTap: () => setState(() => _activeLocalTool = _LocalTool.feather),
          ),
        ],
        if (mask.type == LocalMaskType.brush) ...[
          _ToolButton(
            icon: AppIcons.mask_size,
            label: l10n.localBrushSize,
            isActive: false,
            onTap: () =>
                setState(() => _activeLocalTool = _LocalTool.brushSize),
          ),
          _ToolButton(
            icon: AppIcons.mask_feather,
            label: l10n.localFeather,
            isActive: false,
            onTap: () =>
                setState(() => _activeLocalTool = _LocalTool.brushFeather),
          ),
          _ToolButton(
            icon: AppIcons.gradient_rounded,
            label: l10n.localFlow,
            isActive: _brushFlow < 1.0,
            onTap: () =>
                setState(() => _activeLocalTool = _LocalTool.brushFlow),
          ),
          _ToolButton(
            icon: _brushErase ? AppIcons.remove_circle_outline : AppIcons.add,
            label: _brushErase ? l10n.localErase : l10n.localAdd,
            isActive: _brushErase,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _brushErase = !_brushErase);
            },
          ),
        ],
        _ToolButton(
          icon: AppIcons.exposure_rounded,
          label: l10n.adjExposure,
          isActive: mask.exposure != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.exposure),
        ),
        _ToolButton(
          icon: AppIcons.contrast_rounded,
          label: l10n.adjContrast,
          isActive: mask.contrast != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.contrast),
        ),
        _ToolButton(
          icon: AppIcons.adj_highlights,
          label: l10n.adjHighlights,
          isActive: mask.highlights != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.highlights),
        ),
        _ToolButton(
          icon: AppIcons.adj_shadows,
          label: l10n.adjShadows,
          isActive: mask.shadows != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.shadows),
        ),
        _ToolButton(
          icon: AppIcons.water_drop_outlined,
          label: l10n.adjSaturation,
          isActive: mask.saturation != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.saturation),
        ),
        _ToolButton(
          icon: AppIcons.thermostat_rounded,
          label: l10n.adjWarmth,
          isActive: mask.warmth != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.warmth),
        ),
        _ToolButton(
          icon: AppIcons.invert_colors_rounded,
          label: l10n.adjTint,
          isActive: mask.tint != 0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.tint),
        ),
        _ToolButton(
          icon: AppIcons.mask_feather,
          label: l10n.localAmount,
          isActive: mask.amount != 1.0,
          onTap: () => setState(() => _activeLocalTool = _LocalTool.amount),
        ),
        _ToolButton(
          icon: AppIcons.mask_invert,
          label: l10n.localInvert,
          isActive: mask.inverted,
          onTap: () {
            HapticFeedback.selectionClick();
            _updateSelectedMask(mask.copyWith(inverted: !mask.inverted));
          },
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
    double def = 0.0;
    String label;
    void Function(double) apply;

    switch (tool) {
      case _LocalTool.feather:
        min = 0.0;
        max = 1.0;
        def = 0.5;
        value = mask.feather;
        label = l10n.localFeather;
        apply = (v) => _updateSelectedMask(mask.copyWith(feather: v));
        break;
      case _LocalTool.brushSize:
        min = 0.02;
        max = 0.15;
        def = 0.06;
        value = _brushSize;
        label = l10n.localBrushSize;
        apply = (v) => setState(() => _brushSize = v);
        break;
      case _LocalTool.brushFeather:
        min = 0.0;
        max = 1.0;
        def = 0.6;
        value = _brushFeather;
        label = l10n.localFeather;
        apply = (v) => setState(() => _brushFeather = v);
        break;
      case _LocalTool.brushFlow:
        min = 0.05;
        max = 1.0;
        def = 1.0;
        value = _brushFlow;
        label = l10n.localFlow;
        apply = (v) => setState(() => _brushFlow = v);
        break;
      case _LocalTool.exposure:
        value = mask.exposure;
        label = l10n.adjExposure;
        apply = (v) => _updateSelectedMask(mask.copyWith(exposure: v));
        break;
      case _LocalTool.contrast:
        value = mask.contrast;
        label = l10n.adjContrast;
        apply = (v) => _updateSelectedMask(mask.copyWith(contrast: v));
        break;
      case _LocalTool.shadows:
        value = mask.shadows;
        label = l10n.adjShadows;
        apply = (v) => _updateSelectedMask(mask.copyWith(shadows: v));
        break;
      case _LocalTool.highlights:
        value = mask.highlights;
        label = l10n.adjHighlights;
        apply = (v) => _updateSelectedMask(mask.copyWith(highlights: v));
        break;
      case _LocalTool.saturation:
        value = mask.saturation;
        label = l10n.adjSaturation;
        apply = (v) => _updateSelectedMask(mask.copyWith(saturation: v));
        break;
      case _LocalTool.warmth:
        value = mask.warmth;
        label = l10n.adjWarmth;
        apply = (v) => _updateSelectedMask(mask.copyWith(warmth: v));
        break;
      case _LocalTool.tint:
        value = mask.tint;
        label = l10n.adjTint;
        apply = (v) => _updateSelectedMask(mask.copyWith(tint: v));
        break;
      case _LocalTool.amount:
        min = 0.0;
        max = 1.0;
        def = 1.0;
        value = mask.amount;
        label = l10n.localAmount;
        apply = (v) => _updateSelectedMask(mask.copyWith(amount: v));
        break;
    }

    return _ValueSlider(
      key: const ValueKey('local-slider'),
      label: label,
      value: value,
      min: min,
      max: max,
      defaultValue: def,
      onChanged: apply,
      onClose: () => setState(() => _activeLocalTool = null),
    );
  }

  Widget _buildSlider() {
    final l10n = AppLocalizations.of(context);
    double value = 0;
    double min = -1.0;
    double max = 1.0;
    double def = 0.0;
    String label = '';
    void Function(double) apply;

    switch (_activeTool!) {
      case _AdjustTool.exposure:
        value = _exposure;
        label = l10n.adjExposure;
        apply = (v) => setState(() => _exposure = v);
        break;
      case _AdjustTool.contrast:
        min = 0.5;
        max = 1.5;
        def = 1.0;
        value = _contrast;
        label = l10n.adjContrast;
        apply = (v) => setState(() => _contrast = v);
        break;
      case _AdjustTool.saturation:
        min = 0.0;
        max = 2.0;
        def = 1.0;
        value = _saturation;
        label = l10n.adjSaturation;
        apply = (v) => setState(() => _saturation = v);
        break;
      case _AdjustTool.temperature:
        value = _temperature;
        label = l10n.adjTemperature;
        apply = (v) => setState(() => _temperature = v);
        break;
      case _AdjustTool.tint:
        value = _tint;
        label = l10n.adjTint;
        apply = (v) => setState(() => _tint = v);
        break;
      case _AdjustTool.fade:
        min = 0.0;
        max = 1.0;
        value = _fade;
        label = l10n.adjFade;
        apply = (v) => setState(() => _fade = v);
        break;
      case _AdjustTool.grain:
        min = 0.0;
        max = 1.0;
        value = _grain;
        label = l10n.adjGrain;
        apply = (v) => setState(() => _grain = v);
        break;
      case _AdjustTool.vignette:
        min = 0.0;
        max = 1.0;
        value = _vignette;
        label = l10n.adjVignette;
        apply = (v) => setState(() => _vignette = v);
        break;
      case _AdjustTool.lightLeak:
        min = 0.0;
        max = 1.0;
        value = _lightLeak;
        label = l10n.adjLightLeak;
        apply = (v) => setState(() => _lightLeak = v);
        break;
    }

    return _ValueSlider(
      key: const ValueKey('slider'),
      label: label,
      value: value,
      min: min,
      max: max,
      defaultValue: def,
      onChanged: apply,
      onClose: () => setState(() => _activeTool = null),
      extra: _activeTool == _AdjustTool.lightLeak
          ? _buildLeakDirectionRow()
          : null,
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

/// One entry in the mask row — either a mask that exists or a button that
/// creates one. [isAdd] is what tells those two apart visually.
class _MaskChip extends StatelessWidget {
  const _MaskChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAdd = false,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isAdd;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Colors.white
        : isAdd
            ? Colors.white38
            : Colors.white60;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.white
                : isAdd
                    ? Colors.white12
                    : Colors.white30,
          ),
        ),
        child: Row(
          children: [
            if (isAdd) ...[
              Icon(AppIcons.add, size: 12, color: fg),
              const SizedBox(width: 4),
            ],
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (showDot) ...[
              const SizedBox(width: 6),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one slider panel used by both the global and the per-mask tools.
///
/// Shows the value the way Lightroom does — a signed 0..±100 readout relative
/// to the tool's neutral point rather than the raw internal number — and resets
/// to that neutral point when the readout is tapped.
class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.onChanged,
    required this.onClose,
    this.extra,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final ValueChanged<double> onChanged;
  final VoidCallback onClose;
  final Widget? extra;

  int get _display {
    final span = value >= defaultValue ? max - defaultValue : defaultValue - min;
    if (span <= 0) return 0;
    return ((value - defaultValue) / span * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final display = _display;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Icon(AppIcons.close_rounded, size: 20),
              ),
              GestureDetector(
                onTap: () {
                  if (value == defaultValue) return;
                  HapticFeedback.lightImpact();
                  onChanged(defaultValue);
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      display > 0 ? '+$display' : '$display',
                      style: TextStyle(
                        color: display == 0 ? Colors.white38 : Colors.white70,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Icon(AppIcons.check_rounded, size: 20),
              ),
            ],
          ),
        ),
        ?extra,
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
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
