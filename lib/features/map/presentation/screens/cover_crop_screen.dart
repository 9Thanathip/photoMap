import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

/// Returns the normalized crop rect (left, top, right, bottom in [0,1]) or null if cancelled.
///
/// [provinceAspect] is width/height of the province bounding box — the crop
/// frame will match that aspect ratio so the user sees exactly what will appear
/// on the map.
class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({
    super.key,
    required this.photo,
    required this.provinceName,
    this.provinceAspect = 1.0,
  });

  final PhotoItem photo;
  final String provinceName;
  final double provinceAspect; // width / height

  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  final TransformationController _tc = TransformationController();
  bool _initialized = false;
  double _imageAspect = 1.0; // height / width of source image

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  void _loadImageSize() {
    final entity = widget.photo.assetEntity;
    if (entity == null) return;
    final size = entity.orientatedSize;
    if (mounted) {
      setState(() => _imageAspect = size.height / size.width);
    }
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  /// The fixed crop frame rect in screen space.
  Rect _cropFrame(Size viewport) {
    const hPad = 32.0;
    final availW = viewport.width - hPad * 2;
    // Clamp height so the frame fits above the bottom buttons (~140px)
    final maxH = viewport.height - 200.0 - MediaQuery.of(context).padding.top - 60;
    final frameH = availW / widget.provinceAspect;
    final actualH = frameH.clamp(80.0, maxH);
    final actualW = actualH * widget.provinceAspect;
    return Rect.fromCenter(
      center: Offset(viewport.width / 2, viewport.height / 2 - 30),
      width: actualW,
      height: actualH,
    );
  }

  void _initTransform(Size viewport) {
    if (_initialized) return;
    _initialized = true;
    // Center the image vertically relative to the crop frame center
    final frame = _cropFrame(viewport);
    final displayH = viewport.width * _imageAspect;
    final dy = frame.center.dy - displayH / 2;
    _tc.value = Matrix4.translationValues(0, dy, 0);
  }

  /// Compute normalized crop rect from current transform.
  Rect _computeCrop(Size viewport) {
    final frame = _cropFrame(viewport);
    final inverse = Matrix4.inverted(_tc.value);
    final tl = MatrixUtils.transformPoint(inverse, frame.topLeft);
    final br = MatrixUtils.transformPoint(inverse, frame.bottomRight);
    final displayH = viewport.width * _imageAspect;
    return Rect.fromPoints(
      Offset(
        (tl.dx / viewport.width).clamp(0.0, 1.0),
        (tl.dy / displayH).clamp(0.0, 1.0),
      ),
      Offset(
        (br.dx / viewport.width).clamp(0.0, 1.0),
        (br.dy / displayH).clamp(0.0, 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;
    _initTransform(viewport);

    final displayH = viewport.width * _imageAspect;
    final frame = _cropFrame(viewport);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Pannable image ─────────────────────────────────────────────
          InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.3,
            maxScale: 8.0,
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

          // ── Crop overlay (dim + frame) ─────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CropOverlayPainter(
                  cropRect: frame,
                  provinceAspect: widget.provinceAspect,
                ),
              ),
            ),
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
                      const Text(
                        'Set Cover Photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
          Positioned(
            top: frame.bottom + 12,
            left: 0,
            right: 0,
            child: const Text(
              'Move and pinch to adjust',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _computeCrop(viewport)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Use Photo',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final double provinceAspect;

  const _CropOverlayPainter({
    required this.cropRect,
    required this.provinceAspect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.60);

    // Dim outside crop
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), dim);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom), dim);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), dim);
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height), dim);

    // Frame border
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, border);

    // Rule-of-thirds grid
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (var i = 1; i <= 2; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), grid);
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), grid);
    }

    // Corner handles
    const len = 18.0;
    const thick = 2.5;
    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round;

    void drawCorner(Offset corner, Offset dx, Offset dy) {
      canvas.drawLine(corner, corner + dx, handle);
      canvas.drawLine(corner, corner + dy, handle);
    }

    drawCorner(cropRect.topLeft, const Offset(len, 0), const Offset(0, len));
    drawCorner(cropRect.topRight, const Offset(-len, 0), const Offset(0, len));
    drawCorner(cropRect.bottomLeft, const Offset(len, 0), const Offset(0, -len));
    drawCorner(cropRect.bottomRight, const Offset(-len, 0), const Offset(0, -len));

    // Label showing aspect ratio matches province
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Cover area',
        style: TextStyle(color: Colors.white70, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(
        cropRect.left + (cropRect.width - labelPainter.width) / 2,
        cropRect.top + 6,
      ),
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.cropRect != cropRect || old.provinceAspect != provinceAspect;
}
