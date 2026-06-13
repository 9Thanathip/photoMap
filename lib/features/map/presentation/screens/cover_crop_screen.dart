import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/presentation/widgets/thailand_map_painter.dart';
import 'package:photo_map/l10n/app_localizations.dart';

/// Returns the normalized crop rect (left, top, right, bottom in [0,1]) or null
/// if cancelled.
///
/// The cropper draws the actual province silhouette as the mask so the user can
/// see exactly what will be shown on the map. The returned rect is still the
/// axis-aligned bounding box of the silhouette (that's the contract the map
/// painter expects), but everything outside the silhouette is dimmed so there's
/// no ambiguity about which pixels end up visible.
class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({
    super.key,
    required this.photo,
    required this.provinceName,
  });

  final PhotoItem photo;
  final String provinceName;

  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  bool _initialized = false;
  double _imageAspect = 1.0; // height / width of source image

  // Province shape — loaded once on entry. While it's null we show a loader so
  // the rect-only fallback never flashes.
  Path? _provincePath;
  Rect? _provinceBounds;

  // Cached layout values. Set in _initTransform.
  Size _viewport = Size.zero;
  Rect _frame = Rect.zero;
  double _displayH = 0.0;
  double _minScale = 1.0;
  double _maxScale = 8.0;

  // Live transform of the photo, in screen space. The photo's *base* size is
  // [_viewport.width] × [_displayH]; on screen it is drawn at
  // `_offset + basePoint * _scale`. We own this transform end-to-end (rather
  // than delegating to InteractiveViewer) so we can hard-clamp it every frame
  // — InteractiveViewer fights back when its matrix is rewritten mid-gesture,
  // which is what caused the snap-back on zoom-out.
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Gesture baselines, captured on each onScaleStart.
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  double get _provinceAspect {
    final b = _provinceBounds;
    if (b == null || b.height == 0) return 1.0;
    return b.width / b.height;
  }

  @override
  void initState() {
    super.initState();
    _loadImageSize();
    _loadProvinceShape();
  }

  void _loadImageSize() {
    final entity = widget.photo.assetEntity;
    if (entity == null) return;
    final size = entity.orientatedSize;
    if (mounted) {
      setState(() => _imageAspect = size.height / size.width);
    }
  }

  Future<void> _loadProvinceShape() async {
    final shapes = await loadThailandProvinces();
    if (!mounted) return;
    final target =
        widget.provinceName.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
    ProvinceShape? match;
    for (final s in shapes) {
      if (s.name == target) {
        match = s;
        break;
      }
    }
    if (match == null) return;
    setState(() {
      _provincePath = match!.path;
      _provinceBounds = match.bounds;
      // Re-init transform now that we know the actual frame size.
      _initialized = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// The crop frame rect in screen space — an axis-aligned box matching the
  /// province bounding box's aspect ratio. The silhouette will be scaled to
  /// fill this rect exactly.
  Rect _cropFrame(Size viewport) {
    const hPad = 32.0;
    final availW = viewport.width - hPad * 2;
    final maxH = viewport.height -
        200.0 -
        MediaQuery.of(context).padding.top -
        60;
    final frameH = availW / _provinceAspect;
    final actualH = frameH.clamp(80.0, maxH);
    final actualW = actualH * _provinceAspect;
    return Rect.fromCenter(
      center: Offset(viewport.width / 2, viewport.height / 2 - 30),
      width: actualW,
      height: actualH,
    );
  }

  /// Maps the province path into [frame] (uniform scale, since [frame] already
  /// matches the bounds aspect ratio).
  Path? _displayPath(Rect frame) {
    final path = _provincePath;
    final b = _provinceBounds;
    if (path == null || b == null || b.width == 0 || b.height == 0) {
      return null;
    }
    final scale = frame.width / b.width;
    final matrix = Matrix4.identity()
      ..translateByDouble(frame.left, frame.top, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-b.left, -b.top, 0, 1);
    return path.transform(matrix.storage);
  }

  void _initTransform(Size viewport) {
    if (_initialized) return;
    _initialized = true;

    _viewport = viewport;
    _frame = _cropFrame(viewport);
    _displayH = viewport.width * _imageAspect;

    // The smallest scale at which the image still covers the silhouette frame
    // on both axes. Below this we'd reveal black gaps inside the shape.
    _minScale = math.max(
      _frame.width / viewport.width,
      _frame.height / _displayH,
    );
    _maxScale = math.max(_minScale * 5, 8.0);

    // Centre the image on the frame at the minimum scale.
    _scale = _minScale;
    _offset = Offset(
      _frame.center.dx - viewport.width * _scale / 2,
      _frame.center.dy - _displayH * _scale / 2,
    );
  }

  /// Clamps [offset] so the scaled photo always fully covers the frame: no
  /// photo edge may enter the frame on any side.
  Offset _clampOffset(double scale, Offset offset) {
    final imgW = _viewport.width * scale;
    final imgH = _displayH * scale;
    var dx = offset.dx;
    var dy = offset.dy;
    if (dx > _frame.left) dx = _frame.left;
    if (dx + imgW < _frame.right) dx = _frame.right - imgW;
    if (dy > _frame.top) dy = _frame.top;
    if (dy + imgH < _frame.bottom) dy = _frame.bottom - imgH;
    return Offset(dx, dy);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureStartFocal = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // New scale, hard-clamped to the cover-to-max range.
    final newScale =
        (_gestureStartScale * d.scale).clamp(_minScale, _maxScale);

    // The image-space point under the gesture focal at gesture start. Keeping
    // it pinned under the moving focal gives natural pinch-to-zoom that also
    // follows a one-finger drag (d.scale == 1).
    final imagePoint =
        (_gestureStartFocal - _gestureStartOffset) / _gestureStartScale;
    final rawOffset = d.focalPoint - imagePoint * newScale;

    setState(() {
      _scale = newScale;
      _offset = _clampOffset(newScale, rawOffset);
    });
  }

  /// Compute normalized crop rect (bounding box) from current transform.
  Rect _computeCrop() {
    // Map the frame corners back into the photo's base coordinate space.
    final tlX = (_frame.left - _offset.dx) / _scale;
    final tlY = (_frame.top - _offset.dy) / _scale;
    final brX = (_frame.right - _offset.dx) / _scale;
    final brY = (_frame.bottom - _offset.dy) / _scale;
    return Rect.fromPoints(
      Offset(
        (tlX / _viewport.width).clamp(0.0, 1.0),
        (tlY / _displayH).clamp(0.0, 1.0),
      ),
      Offset(
        (brX / _viewport.width).clamp(0.0, 1.0),
        (brY / _displayH).clamp(0.0, 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;
    final l10n = AppLocalizations.of(context);

    final shapeReady = _provincePath != null;
    if (shapeReady) _initTransform(viewport);

    final displayH = viewport.width * _imageAspect;
    final frame = shapeReady ? _cropFrame(viewport) : Rect.zero;
    final displayPath = shapeReady ? _displayPath(frame) : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Pannable image ─────────────────────────────────────────────
          if (shapeReady)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: Matrix4.identity()
                      ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                      ..scaleByDouble(_scale, _scale, 1, 1),
                    child: SizedBox(
                      width: viewport.width,
                      height: displayH,
                      child: widget.photo.assetEntity != null
                          ? Image(
                              image: AssetEntityImageProvider(
                                widget.photo.assetEntity!,
                                isOriginal: true,
                              ),
                              fit: BoxFit.fill,
                              width: viewport.width,
                              height: displayH,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),

          // ── Province silhouette mask ───────────────────────────────────
          if (displayPath != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ShapeMaskPainter(
                    shape: displayPath,
                    frame: frame,
                  ),
                ),
              ),
            ),

          // ── Loading state ──────────────────────────────────────────────
          if (!shapeReady)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // ── Top bar ────────────────────────────────────────────────────
          Positioned(
            top: topPad + 4,
            left: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        l10n.coverSetTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.provinceName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // ── Instruction ────────────────────────────────────────────────
          if (shapeReady)
            Positioned(
              top: frame.bottom + 12,
              left: 0,
              right: 0,
              child: Text(
                l10n.coverAdjustHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),

          // ── Bottom buttons ─────────────────────────────────────────────
          Positioned(
            bottom: botPad + 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: shapeReady
                        ? () => Navigator.pop(context, _computeCrop())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.coverUsePhoto,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
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

class _ShapeMaskPainter extends CustomPainter {
  const _ShapeMaskPainter({required this.shape, required this.frame});

  final Path shape;
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    // Dim everything outside the province silhouette.
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      shape,
    );
    canvas.drawPath(outside, dim);

    // Subtle bounding hint so the user can feel the framing area while
    // panning — kept very faint so the silhouette stays the dominant cue.
    final boundsHint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dashed = _dashedRect(frame);
    canvas.drawPath(dashed, boundsHint);

    // Province silhouette outline — the primary visual reference.
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(shape, outline);

    // Soft inner glow so the shape edge separates from busy photos.
    final glow = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);
    canvas.drawPath(shape, glow);
  }

  Path _dashedRect(Rect r) {
    const dash = 4.0;
    const gap = 4.0;
    final p = Path();
    void run(double from, double to, bool horizontal, double fixed) {
      var pos = from;
      while (pos < to) {
        final end = (pos + dash).clamp(from, to);
        if (horizontal) {
          p.moveTo(pos, fixed);
          p.lineTo(end, fixed);
        } else {
          p.moveTo(fixed, pos);
          p.lineTo(fixed, end);
        }
        pos += dash + gap;
      }
    }

    run(r.left, r.right, true, r.top);
    run(r.left, r.right, true, r.bottom);
    run(r.top, r.bottom, false, r.left);
    run(r.top, r.bottom, false, r.right);
    return p;
  }

  @override
  bool shouldRepaint(_ShapeMaskPainter old) =>
      old.shape != shape || old.frame != frame;
}
