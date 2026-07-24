import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../utils/color_matrix_utils.dart';

/// Lightroom-style local adjustments: a mask (radial / linear / brush) scopes
/// a set of tonal tweaks to part of the image. All geometry is stored in
/// normalized image space (0..1 on both axes, radii as a fraction of the
/// shortest side) so the interactive preview and the full-resolution export
/// paint pixel-identical results from the same data.
enum LocalMaskType { radial, linear, brush }

/// One stroke of a brush mask, in normalized image space.
class BrushStroke {
  const BrushStroke({required this.points, required this.radius});

  final List<Offset> points; // normalized 0..1
  final double radius; // fraction of shortest side

  BrushStroke copyWith({List<Offset>? points, double? radius}) => BrushStroke(
        points: points ?? this.points,
        radius: radius ?? this.radius,
      );
}

/// A single local-adjust mask and its tonal values.
///
/// Tonal ranges (all 0 = neutral):
/// - [exposure]  -1..1  linear brightness offset
/// - [shadows]   -1..1  lifts (+) or deepens (-) blacks, whites untouched
/// - [highlights]-1..1  boosts (+) or compresses (-) brights, blacks untouched
/// - [warmth]    -1..1  warm (+) / cool (-)
class LocalMask {
  const LocalMask({
    required this.id,
    required this.type,
    this.center = const Offset(0.5, 0.5),
    this.radius = 0.25,
    this.feather = 0.5,
    this.linearStart = const Offset(0.5, 0.25),
    this.linearEnd = const Offset(0.5, 0.75),
    this.strokes = const [],
    this.exposure = 0.0,
    this.shadows = 0.0,
    this.highlights = 0.0,
    this.warmth = 0.0,
  });

  final int id;
  final LocalMaskType type;

  // Radial geometry.
  final Offset center; // normalized
  final double radius; // fraction of shortest side
  final double feather; // 0 hard edge .. 1 full fade from center

  // Linear geometry: full effect at [linearStart], fades to none at [linearEnd].
  final Offset linearStart;
  final Offset linearEnd;

  // Brush geometry.
  final List<BrushStroke> strokes;

  // Tonal values.
  final double exposure;
  final double shadows;
  final double highlights;
  final double warmth;

  bool get hasEffect =>
      exposure != 0 || shadows != 0 || highlights != 0 || warmth != 0;

  LocalMask copyWith({
    Offset? center,
    double? radius,
    double? feather,
    Offset? linearStart,
    Offset? linearEnd,
    List<BrushStroke>? strokes,
    double? exposure,
    double? shadows,
    double? highlights,
    double? warmth,
  }) =>
      LocalMask(
        id: id,
        type: type,
        center: center ?? this.center,
        radius: radius ?? this.radius,
        feather: feather ?? this.feather,
        linearStart: linearStart ?? this.linearStart,
        linearEnd: linearEnd ?? this.linearEnd,
        strokes: strokes ?? this.strokes,
        exposure: exposure ?? this.exposure,
        shadows: shadows ?? this.shadows,
        highlights: highlights ?? this.highlights,
        warmth: warmth ?? this.warmth,
      );

  /// The combined colour matrix for this mask's tonal values.
  ///
  /// Shadows/highlights are luminance-shaped with pure matrices:
  /// - shadow lift  (v>0):  out = in(1-c) + c   (screen with constant — moves
  ///   blacks by c, leaves whites)
  /// - shadow deepen(v<0):  out = in(1+c) - c   (inverse — blacks drop, whites
  ///   stay)
  /// - highlight    (v):    out = in(1+g)       (gain scales brights most,
  ///   blacks unmoved)
  ColorMatrix get matrix {
    ColorMatrix m = ColorMatrix.identity;
    if (exposure != 0) m = m.multiply(ColorMatrix.exposure(exposure * 0.6));
    if (shadows != 0) {
      final c = shadows.abs() * 0.45;
      final gain = shadows > 0 ? 1.0 - c : 1.0 + c;
      final off = (shadows > 0 ? c : -c) * 255.0;
      m = m.multiply(ColorMatrix([
        gain, 0, 0, 0, off,
        0, gain, 0, 0, off,
        0, 0, gain, 0, off,
        0, 0, 0, 1, 0,
      ]));
    }
    if (highlights != 0) {
      final gain = 1.0 + highlights * 0.35;
      m = m.multiply(ColorMatrix([
        gain, 0, 0, 0, 0,
        0, gain, 0, 0, 0,
        0, 0, gain, 0, 0,
        0, 0, 0, 1, 0,
      ]));
    }
    if (warmth != 0) m = m.multiply(ColorMatrix.temperature(warmth * 0.8));
    return m;
  }

  /// Paints this mask's alpha (white = full effect) into [rect].
  void paintMaskAlpha(Canvas canvas, Rect rect, Paint paint) {
    final shortest = rect.shortestSide;
    switch (type) {
      case LocalMaskType.radial:
        final c = Offset(
          rect.left + center.dx * rect.width,
          rect.top + center.dy * rect.height,
        );
        final r = radius * shortest;
        // Feather controls where the fade starts: 0 → hard disc, 1 → fade
        // from the very center.
        final inner = (1.0 - feather).clamp(0.0, 0.99);
        paint.shader = ui.Gradient.radial(
          c,
          r,
          [Colors.white, Colors.white, Colors.white.withValues(alpha: 0.0)],
          [0.0, inner, 1.0],
        );
        canvas.drawRect(rect, paint);
        break;
      case LocalMaskType.linear:
        final a = Offset(
          rect.left + linearStart.dx * rect.width,
          rect.top + linearStart.dy * rect.height,
        );
        final b = Offset(
          rect.left + linearEnd.dx * rect.width,
          rect.top + linearEnd.dy * rect.height,
        );
        paint.shader = ui.Gradient.linear(
          a,
          b,
          [Colors.white, Colors.white.withValues(alpha: 0.0)],
        );
        canvas.drawRect(rect, paint);
        break;
      case LocalMaskType.brush:
        for (final stroke in strokes) {
          if (stroke.points.isEmpty) continue;
          final r = stroke.radius * shortest;
          final strokePaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..blendMode = paint.blendMode
            // Soft edge so brushed areas blend like a feathered Lightroom brush.
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, r * 0.6);
          final path = Path();
          final first = _toRect(stroke.points.first, rect);
          path.moveTo(first.dx, first.dy);
          if (stroke.points.length == 1) {
            // Single tap → dot.
            path.lineTo(first.dx + 0.1, first.dy + 0.1);
          } else {
            for (final p in stroke.points.skip(1)) {
              final abs = _toRect(p, rect);
              path.lineTo(abs.dx, abs.dy);
            }
          }
          canvas.drawPath(path, strokePaint);
        }
        break;
    }
  }

  static Offset _toRect(Offset norm, Rect rect) => Offset(
        rect.left + norm.dx * rect.width,
        rect.top + norm.dy * rect.height,
      );
}

/// Composites every mask's adjusted version of [image] over what is already
/// on [canvas]. The caller draws the globally-graded base first; each mask
/// then re-draws the image through baseMatrix * its own matrix (so masked
/// regions keep the global grade), clipped to the mask's alpha via dstIn
/// inside a saveLayer.
void paintLocalMasks(
  Canvas canvas,
  Rect rect,
  ui.Image image,
  List<LocalMask> masks,
  ColorMatrix baseMatrix,
) {
  for (final mask in masks) {
    if (!mask.hasEffect) continue;
    canvas.saveLayer(rect, Paint());
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()
        ..colorFilter =
            ColorFilter.matrix(baseMatrix.multiply(mask.matrix).matrix)
        ..filterQuality = FilterQuality.high,
    );
    mask.paintMaskAlpha(canvas, rect, Paint()..blendMode = BlendMode.dstIn);
    canvas.restore();
  }
}

/// Live-preview painter: local masks over the globally-graded base image,
/// plus the red coverage overlay for the mask being edited.
class LocalMasksPainter extends CustomPainter {
  const LocalMasksPainter({
    required this.image,
    required this.masks,
    required this.baseMatrix,
    this.overlayMask,
  });

  final ui.Image image;
  final List<LocalMask> masks;
  final ColorMatrix baseMatrix;
  final LocalMask? overlayMask;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    paintLocalMasks(canvas, rect, image, masks, baseMatrix);
    if (overlayMask != null) {
      paintMaskOverlay(canvas, rect, overlayMask!);
    }
  }

  @override
  bool shouldRepaint(LocalMasksPainter old) =>
      old.image != image ||
      old.masks != masks ||
      old.baseMatrix != baseMatrix ||
      old.overlayMask != overlayMask;
}

/// Red overlay visualizing the selected mask's coverage (Lightroom-style),
/// plus geometry handles for radial and linear masks.
void paintMaskOverlay(Canvas canvas, Rect rect, LocalMask mask) {
  // Coverage tint: paint the mask alpha in red at reduced opacity.
  canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: 0.45));
  canvas.drawRect(rect, Paint()..color = const Color(0xFFFF3B30));
  mask.paintMaskAlpha(canvas, rect, Paint()..blendMode = BlendMode.dstIn);
  canvas.restore();

  final handlePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final dotPaint = Paint()..color = Colors.white;

  switch (mask.type) {
    case LocalMaskType.radial:
      final c = LocalMask._toRect(mask.center, rect);
      canvas.drawCircle(c, mask.radius * rect.shortestSide, handlePaint);
      canvas.drawCircle(c, 5, dotPaint);
      break;
    case LocalMaskType.linear:
      final a = LocalMask._toRect(mask.linearStart, rect);
      final b = LocalMask._toRect(mask.linearEnd, rect);
      // Guide lines perpendicular to the gradient axis at both handles.
      final dir = (b - a);
      if (dir.distance > 0.001) {
        final n = Offset(-dir.dy, dir.dx) / dir.distance;
        final len = rect.longestSide;
        for (final p in [a, b]) {
          canvas.drawLine(p - n * len, p + n * len, handlePaint);
        }
      }
      canvas.drawCircle(a, 6, dotPaint);
      canvas.drawCircle(b, 6, dotPaint);
      break;
    case LocalMaskType.brush:
      // Coverage tint alone is the visual — strokes have no handles.
      break;
  }
}
