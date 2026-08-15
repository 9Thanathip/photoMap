import 'dart:io';
import 'package:photo_map/core/theme/app_icons.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'package:photo_map/common_widgets/app_snack.dart';
import 'package:photo_map/common_widgets/asset_thumb.dart';
import 'package:photo_map/common_widgets/glass_sheet.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import '../../providers/gallery_notifier.dart';
import 'collage_painter.dart';
import 'collage_ratio.dart';
import 'collage_transform.dart';

/// Grid collage builder. The user picks a rows×cols grid (equal cells), taps a
/// cell to fill it with a photo, frames each one in place (drag to reposition,
/// two fingers to zoom and straighten), and tunes the aspect ratio, gap and
/// background. Exports via canvas → PNG → save/share (same path as the frame
/// exporter).
class CollageBuilderScreen extends ConsumerStatefulWidget {
  const CollageBuilderScreen({super.key});

  @override
  ConsumerState<CollageBuilderScreen> createState() =>
      _CollageBuilderScreenState();
}

class _CollageBuilderScreenState extends ConsumerState<CollageBuilderScreen> {
  static const _minAxis = 1;
  static const _maxAxis = 10;

  int _rows = 2;
  int _cols = 2;
  int _revision = 0;

  CollageRatio _ratio = CollageRatio.square;
  double _gapFraction = 0.012;
  Color _bg = Colors.white;

  /// Photos by cell index. Kept as a map so it survives grid resizes (cells
  /// beyond the new count are simply not drawn).
  final Map<int, ui.Image> _images = {};
  final Map<int, String> _paths = {};

  /// How each photo is framed inside its cell. Absent = plain centre crop.
  final Map<int, CellTransform> _transforms = {};

  String _busy = '';
  Size _canvasSize = Size.zero;

  // Drag-to-swap state (long-press a filled cell, drag onto another).
  int? _dragFrom;
  Offset? _dragPos;
  int? _dragTarget;

  // In-cell framing state (drag / pinch / twist on a filled cell).
  int? _framing;
  CellTransform _frameBase = const CellTransform();
  Offset _framePan = Offset.zero;

  CollageGrid get _grid => CollageGrid(_rows, _cols);

  static const _bgSwatches = <Color>[
    Colors.white,
    Color(0xFFF2EDE4),
    Color(0xFFBFC4CC),
    Color(0xFF1A1A1A),
    Colors.black,
    Color(0xFF0E1A2B),
  ];

  @override
  void dispose() {
    for (final img in _images.values) {
      img.dispose();
    }
    super.dispose();
  }

  double _gapPx(Size box) => _gapFraction * box.shortestSide;

  void _setRows(int v) => setState(() => _rows = v.clamp(_minAxis, _maxAxis));
  void _setCols(int v) => setState(() => _cols = v.clamp(_minAxis, _maxAxis));

  Future<List<PhotoItem>?> _openPicker({
    required bool multi,
    int capacity = 1,
  }) {
    final photos = ref.read(galleryStateProvider).allPhotos;
    return showModalBottomSheet<List<PhotoItem>>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PhotoPickerSheet(
        photos: photos,
        multi: multi,
        capacity: capacity,
        total: _grid.count,
        filled: _images.keys.where((i) => i < _grid.count).length,
      ),
    );
  }

  Future<void> _pickPhotoFor(int index) async {
    final res = await _openPicker(multi: false);
    final picked = (res != null && res.isNotEmpty) ? res.first : null;
    if (picked?.assetEntity == null) return;
    final img = await _decode(picked!);
    if (img == null || !mounted) return;
    setState(() {
      _images[index]?.dispose();
      _images[index] = img;
      _paths[index] = picked.path;
      // Framing belongs to the photo that was framed, not to the cell.
      _transforms.remove(index);
      _revision++;
    });
  }

  /// Picks several photos and drops them into the empty cells, left to right.
  Future<void> _pickMultiple() async {
    final targets = [
      for (var i = 0; i < _grid.count; i++)
        if (!_images.containsKey(i)) i,
    ];
    if (targets.isEmpty) return;
    final res = await _openPicker(multi: true, capacity: targets.length);
    if (res == null || res.isEmpty) return;
    var t = 0;
    for (final p in res) {
      if (t >= targets.length) break;
      if (p.assetEntity == null) continue;
      final img = await _decode(p);
      if (img == null) continue;
      if (!mounted) {
        img.dispose();
        return;
      }
      final idx = targets[t++];
      _images[idx]?.dispose();
      _images[idx] = img;
      _paths[idx] = p.path;
    }
    if (mounted) setState(() => _revision++);
  }

  Future<ui.Image?> _decode(PhotoItem photo) async {
    final bytes = await photo.assetEntity!.thumbnailDataWithSize(
      const ThumbnailSize(1280, 1280),
    );
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  int? _cellAt(Offset point) =>
      _grid.indexAt(point, Offset.zero & _canvasSize, _gapPx(_canvasSize));

  Rect _cellRect(int index) =>
      _grid.cellRect(index, Offset.zero & _canvasSize, _gapPx(_canvasSize));

  void _onTapUp(TapUpDetails d) {
    final index = _cellAt(d.localPosition);
    if (index != null) _pickPhotoFor(index);
  }

  // ── Drag to swap ────────────────────────────────────────────────────────
  void _onDragStart(LongPressStartDetails d) {
    final i = _cellAt(d.localPosition);
    if (i != null && _images.containsKey(i)) {
      HapticFeedback.mediumImpact();
      setState(() {
        _dragFrom = i;
        _dragPos = d.localPosition;
        _dragTarget = i;
      });
    }
  }

  void _onDragUpdate(LongPressMoveUpdateDetails d) {
    if (_dragFrom == null) return;
    setState(() {
      _dragPos = d.localPosition;
      _dragTarget = _cellAt(d.localPosition);
    });
  }

  void _onDragEnd(LongPressEndDetails d) {
    final from = _dragFrom;
    final to = _dragTarget;
    if (from != null && to != null && from != to) _swap(from, to);
    setState(() {
      _dragFrom = null;
      _dragPos = null;
      _dragTarget = null;
    });
  }

  void _swap(int a, int b) {
    final ia = _images[a], ib = _images[b];
    final pa = _paths[a], pb = _paths[b];
    final ta = _transforms[a], tb = _transforms[b];
    ib != null ? _images[a] = ib : _images.remove(a);
    ia != null ? _images[b] = ia : _images.remove(b);
    pb != null ? _paths[a] = pb : _paths.remove(a);
    pa != null ? _paths[b] = pa : _paths.remove(b);
    tb != null ? _transforms[a] = tb : _transforms.remove(a);
    ta != null ? _transforms[b] = ta : _transforms.remove(b);
    _revision++;
  }

  // ── Frame a photo inside its cell ───────────────────────────────────────
  /// Drag repositions the crop, two fingers zoom and straighten it.
  ///
  /// All three run off the scale recognizer alone: it reports a one-finger drag
  /// through [ScaleUpdateDetails.focalPointDelta], so pan and pinch stay a
  /// single gesture. Holding still instead lets the long-press swap take the
  /// arena, which is what keeps both interactions on the same canvas.
  void _onFrameStart(ScaleStartDetails d) {
    final i = _cellAt(d.localFocalPoint);
    if (i == null || !_images.containsKey(i)) {
      _framing = null;
      return;
    }
    setState(() {
      _framing = i;
      _frameBase = _transforms[i] ?? const CellTransform();
      _framePan = Offset.zero;
    });
  }

  void _onFrameUpdate(ScaleUpdateDetails d) {
    final i = _framing;
    final img = i == null ? null : _images[i];
    if (i == null || img == null) return;

    _framePan += d.focalPointDelta;
    var rotation = _frameBase.rotation + d.rotation;
    final straight = rotation.abs() < kCellStraightenSnap;
    if (straight) rotation = 0;

    final cell = _cellRect(i);
    final next = CellTransform(
      scale: (_frameBase.scale * d.scale).clamp(1.0, kCellMaxZoom),
      rotation: rotation,
      offset: _frameBase.offset + _framePan / cell.width,
    );
    // Clamped as it is built, so the photo can never be dragged far enough to
    // show background — the drag just stops at the edge.
    final framed = next.copyWith(
      offset: clampCellPan(
        next,
        image: Size(img.width.toDouble(), img.height.toDouble()),
        cell: cell.size,
      ),
    );
    if (framed == _transforms[i]) return;
    if (straight && (_transforms[i]?.rotation ?? 0) != 0) {
      HapticFeedback.selectionClick(); // landed back on level
    }
    setState(() {
      _transforms[i] = framed;
      _revision++;
    });
  }

  void _onFrameEnd(ScaleEndDetails d) {
    if (_framing == null) return;
    setState(() => _framing = null);
  }

  bool get _hasFraming => _transforms.values.any((t) => !t.isIdentity);

  void _resetFraming() {
    if (!_hasFraming) return;
    HapticFeedback.selectionClick();
    setState(() {
      _transforms.clear();
      _revision++;
    });
  }

  // ── Sort by colour ──────────────────────────────────────────────────────
  /// Reorders the placed photos into a smooth colour gradient by dominant hue,
  /// then lays them back into the cells in reading order (left→right, top→
  /// bottom). Empty cells fall to the end.
  Future<void> _sortByColor() async {
    if (_busy.isNotEmpty) return;
    setState(() => _busy = 'sort');
    try {
      final placed = <
          ({
            ui.Image img,
            String path,
            CellTransform? frame,
            double hue,
            double val
          })>[];
      for (var i = 0; i < _grid.count; i++) {
        final img = _images[i];
        final path = _paths[i];
        if (img == null || path == null) continue;
        final tone = await _dominantTone(img);
        placed.add((
          img: img,
          path: path,
          frame: _transforms[i],
          hue: tone.$1,
          val: tone.$2,
        ));
      }
      if (placed.length < 2) return;
      // Primary key hue (the gradient), secondary lightness so near-grey frames
      // don't scatter.
      placed.sort((a, b) {
        final h = a.hue.compareTo(b.hue);
        return h != 0 ? h : a.val.compareTo(b.val);
      });
      final imgs = <int, ui.Image>{};
      final paths = <int, String>{};
      final frames = <int, CellTransform>{};
      for (var k = 0; k < placed.length; k++) {
        imgs[k] = placed[k].img;
        paths[k] = placed[k].path;
        final frame = placed[k].frame;
        if (frame != null) frames[k] = frame;
      }
      if (!mounted) return;
      setState(() {
        _images
          ..clear()
          ..addAll(imgs);
        _paths
          ..clear()
          ..addAll(paths);
        _transforms
          ..clear()
          ..addAll(frames);
        _revision++;
      });
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  /// Average colour of [img] as (hue 0..360, value 0..1). Downscales to 8×8 on
  /// the GPU first so the averaging is cheap.
  Future<(double, double)> _dominantTone(ui.Image img) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final small = await recorder.endRecording().toImage(8, 8);
    final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    small.dispose();
    if (data == null) return (0.0, 0.0);
    final b = data.buffer.asUint8List();
    var r = 0.0, g = 0.0, bl = 0.0;
    final n = b.length ~/ 4;
    for (var i = 0; i < b.length; i += 4) {
      r += b[i];
      g += b[i + 1];
      bl += b[i + 2];
    }
    final color = Color.fromARGB(
      255,
      (r / n).round(),
      (g / n).round(),
      (bl / n).round(),
    );
    final hsv = HSVColor.fromColor(color);
    return (hsv.hue, hsv.value);
  }

  // ── Export ────────────────────────────────────────────────────────────────
  Size _exportSize() {
    const long = 2560.0;
    final r = _ratio.value;
    return r >= 1 ? Size(long, long / r) : Size(long * r, long);
  }

  Future<Uint8List?> _renderPng() async {
    final size = _exportSize();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    paintCollage(
      canvas,
      Offset.zero & size,
      grid: _grid,
      gap: _gapFraction * size.shortestSide,
      background: _bg,
      images: _images,
      transforms: _transforms,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List();
  }

  bool get _hasPhoto => _images.keys.any((i) => i < _grid.count);

  Future<void> _save() async {
    if (_busy.isNotEmpty) return;
    setState(() => _busy = 'save');
    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    try {
      final png = await _renderPng();
      if (png == null) throw StateError('encode failed');
      final filename =
          'jaruek_collage_${DateTime.now().millisecondsSinceEpoch}.png';
      await PhotoManager.editor.saveImage(
        png,
        filename: filename,
        title: filename,
        desc: 'Collage in Jaruek',
      );
      AppSnack.showOnOverlay(overlay, l10n.frameSaved);
    } catch (_) {
      AppSnack.showOnOverlay(
        overlay,
        l10n.frameSaveFailed,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _share() async {
    if (_busy.isNotEmpty) return;
    setState(() => _busy = 'share');
    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    try {
      final png = await _renderPng();
      if (png == null) throw StateError('encode failed');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/jaruek_collage_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      AppSnack.showOnOverlay(
        overlay,
        l10n.frameSaveFailed,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: t.surfaceBase,
        // bottom: false so our own bottom padding is the only inset — avoids a
        // double gap that floated the action bar above the screen edge.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(l10n, t),
              Expanded(child: _buildCanvas(t)),
              _buildFrameHint(l10n, t),
              _buildGridPicker(l10n, t),
              _buildPhotoTools(l10n, t),
              _buildRatioPicker(t),
              _buildGapAndColor(l10n, t),
              _buildActions(l10n, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, AppTokens t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: t.textSecondary),
            child: Text(
              l10n.commonCancel,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            l10n.collageTitle,
            style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          TextButton.icon(
            onPressed: _pickMultiple,
            style: TextButton.styleFrom(foregroundColor: t.textPrimary),
            icon: const Icon(AppIcons.add_photo_alternate_outlined, size: 18),
            label: Text(
              l10n.collageAddPhotos,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(AppTokens t) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: _ratio.value,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = constraints.biggest;
              return GestureDetector(
                onTapUp: _onTapUp,
                onLongPressStart: _onDragStart,
                onLongPressMoveUpdate: _onDragUpdate,
                onLongPressEnd: _onDragEnd,
                onScaleStart: _onFrameStart,
                onScaleUpdate: _onFrameUpdate,
                onScaleEnd: _onFrameEnd,
                child: CustomPaint(
                  painter: CollagePainter(
                    grid: _grid,
                    gap: _gapPx(_canvasSize),
                    background: _bg,
                    images: _images,
                    transforms: _transforms,
                    selected: _framing,
                    placeholder: t.surfaceElevated,
                    revision: _revision,
                    dragImage: _dragFrom != null ? _images[_dragFrom] : null,
                    dragTransform:
                        _dragFrom != null ? _transforms[_dragFrom] : null,
                    dragCenter: _dragPos,
                    dragTarget: (_dragFrom != null && _dragTarget != _dragFrom)
                        ? _dragTarget
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Tells the user the cells can be framed at all — the gestures are the same
  /// ones the canvas already answers for swapping, so nothing on screen would
  /// otherwise hint at them.
  Widget _buildFrameHint(AppLocalizations l10n, AppTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
      child: Text(
        _hasPhoto ? l10n.collageFrameHint : l10n.collageEmptyHint,
        textAlign: TextAlign.center,
        style: TextStyle(color: t.textTertiary, fontSize: 11, height: 1.3),
      ),
    );
  }

  /// Colour sort + framing reset: both act on the photos already placed, so
  /// they share a row and each stays dim until it has something to act on.
  Widget _buildPhotoTools(AppLocalizations l10n, AppTokens t) {
    final canSort =
        _busy.isEmpty &&
        (_images.keys.where((i) => i < _grid.count).length >= 2);
    final style = TextButton.styleFrom(
      foregroundColor: t.textPrimary,
      disabledForegroundColor: t.textTertiary,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: canSort ? _sortByColor : null,
          style: style,
          icon: _busy == 'sort'
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.textPrimary,
                  ),
                )
              : const Icon(AppIcons.gradient_rounded, size: 18),
          label: Text(
            l10n.collageColorSort,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        TextButton.icon(
          onPressed: _hasFraming ? _resetFraming : null,
          style: style,
          icon: const Icon(AppIcons.center_focus_strong_outlined, size: 18),
          label: Text(
            l10n.collageResetFraming,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildGridPicker(AppLocalizations l10n, AppTokens t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      // Expanded halves keep the '×' at the true horizontal centre even though
      // the Thai row/col labels differ in width.
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _stepper(t, l10n.collageRows, _rows, (v) => _setRows(v)),
            ),
          ),
          const SizedBox(width: 12),
          Text('×', style: TextStyle(color: t.textTertiary, fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _stepper(t, l10n.collageCols, _cols, (v) => _setCols(v)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper(
    AppTokens t,
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 12)),
        const SizedBox(width: 8),
        _stepBtn(
          t,
          AppIcons.remove_rounded,
          value > _minAxis ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _stepBtn(
          t,
          AppIcons.add_rounded,
          value < _maxAxis ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Widget _stepBtn(AppTokens t, IconData icon, VoidCallback? onTap) {
    final on = onTap != null;
    return GestureDetector(
      onTap: () {
        if (on) HapticFeedback.selectionClick();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? t.surfaceElevated : t.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: on ? t.textPrimary : t.textTertiary),
      ),
    );
  }

  Widget _buildRatioPicker(AppTokens t) {
    return SizedBox(
      height: 60,
      child: Center(
        child: ListView(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final r in CollageRatio.values)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _ratio = r);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 58,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: r.value >= 1 ? 32 : 32 * r.value,
                        height: r.value >= 1 ? 32 / r.value : 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _ratio == r ? t.textPrimary : t.textTertiary,
                            width: _ratio == r ? 2 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.label,
                        style: TextStyle(
                          color: _ratio == r ? t.textPrimary : t.textSecondary,
                          fontSize: 11,
                          fontWeight: _ratio == r
                              ? FontWeight.w700
                              : FontWeight.w500,
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

  Widget _buildGapAndColor(AppLocalizations l10n, AppTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              l10n.collageGap,
              style: TextStyle(color: t.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: t.textPrimary,
                inactiveTrackColor: t.textTertiary,
                thumbColor: t.textPrimary,
                overlayColor: t.textPrimary.withValues(alpha: 0.1),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _gapFraction,
                max: 0.05,
                onChanged: (v) => setState(() => _gapFraction = v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          for (final c in _bgSwatches)
            GestureDetector(
              onTap: () => setState(() => _bg = c),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _bg == c ? t.textPrimary : t.borderStrong,
                    width: _bg == c ? 2 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(AppLocalizations l10n, AppTokens t) {
    final ready = _busy.isEmpty && _hasPhoto;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: ready ? _share : null,
              icon: _busy == 'share'
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.textPrimary,
                      ),
                    )
                  : const Icon(AppIcons.ios_share_rounded, size: 18),
              label: Text(l10n.frameShare),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.textPrimary,
                side: BorderSide(color: t.borderStrong),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: ready ? _save : null,
              icon: _busy == 'save'
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.surfaceBase,
                      ),
                    )
                  : const Icon(AppIcons.download_rounded, size: 18),
              label: Text(l10n.frameSave),
              style: FilledButton.styleFrom(
                backgroundColor: t.textPrimary,
                foregroundColor: t.surfaceBase,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet grid to pick photos for collage cells. In [multi] mode the user
/// taps to toggle several (numbered by pick order) then confirms; otherwise the
/// first tap returns immediately. Always pops a `List<PhotoItem>`.
class _PhotoPickerSheet extends StatefulWidget {
  const _PhotoPickerSheet({
    required this.photos,
    required this.multi,
    required this.capacity,
    required this.total,
    required this.filled,
  });

  final List<PhotoItem> photos;
  final bool multi;

  /// Max photos selectable (= empty cells in the grid).
  final int capacity;

  /// Total cells in the grid, and how many are already filled — shown so the
  /// user knows how many more will fit.
  final int total;
  final int filled;

  @override
  State<_PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends State<_PhotoPickerSheet> {
  final List<PhotoItem> _selected = [];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    final images = widget.photos.where((p) => p.assetEntity != null).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => GlassSheet(
        child: Column(
          children: [
            if (widget.multi)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selected.length} / ${widget.capacity}',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l10n.collagePickerHint(widget.filled, widget.total),
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, _selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.textPrimary,
                        foregroundColor: t.surfaceBase,
                      ),
                      child: Text(l10n.commonDone),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: images.length,
                itemBuilder: (context, i) {
                  final p = images[i];
                  final order = _selected.indexOf(p);
                  return GestureDetector(
                    onTap: () {
                      if (!widget.multi) {
                        Navigator.pop(context, [p]);
                        return;
                      }
                      if (order < 0 && _selected.length >= widget.capacity) {
                        HapticFeedback.lightImpact();
                        return; // grid full — no more slots
                      }
                      setState(() {
                        order >= 0 ? _selected.remove(p) : _selected.add(p);
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AssetThumb(asset: p.assetEntity!, maxPixels: 800),
                        if (widget.multi && order >= 0) ...[
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4C9AFF),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${order + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
