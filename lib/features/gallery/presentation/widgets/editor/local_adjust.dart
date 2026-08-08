import 'dart:math' as math;
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
  const BrushStroke({
    required this.points,
    required this.radius,
    this.erase = false,
    this.feather = 0.6,
    this.flow = 1.0,
  });

  final List<Offset> points; // normalized 0..1
  final double radius; // fraction of shortest side

  /// Erase strokes carve coverage back out of the mask (Lightroom's
  /// Add / Erase pair) instead of adding to it.
  final bool erase;

  /// Edge softness as a fraction of the radius — 0 is a hard-edged stamp.
  final double feather;

  /// Coverage laid down per stroke, 0..1 (Lightroom's Flow). Both are baked in
  /// when the stroke is committed, so changing the tool later never rewrites
  /// strokes already painted.
  final double flow;

  BrushStroke copyWith({
    List<Offset>? points,
    double? radius,
    bool? erase,
    double? feather,
    double? flow,
  }) =>
      BrushStroke(
        points: points ?? this.points,
        radius: radius ?? this.radius,
        erase: erase ?? this.erase,
        feather: feather ?? this.feather,
        flow: flow ?? this.flow,
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
    this.radiusY = 0.25,
    this.angle = 0.0,
    this.feather = 0.5,
    this.linearStart = const Offset(0.5, 0.25),
    this.linearEnd = const Offset(0.5, 0.75),
    this.strokes = const [],
    this.exposure = 0.0,
    this.contrast = 0.0,
    this.shadows = 0.0,
    this.highlights = 0.0,
    this.saturation = 0.0,
    this.warmth = 0.0,
    this.tint = 0.0,
    this.amount = 1.0,
    this.inverted = false,
  });

  final int id;
  final LocalMaskType type;

  // Radial geometry — an ellipse, so the two axes are sized independently and
  // the whole shape can be rotated (Lightroom's radial handles).
  final Offset center; // normalized
  final double radius; // x radius, fraction of shortest side
  final double radiusY; // y radius, fraction of shortest side
  final double angle; // radians, clockwise in screen space
  final double feather; // 0 hard edge .. 1 full fade from center

  // Linear geometry: full effect at [linearStart], fades to none at [linearEnd].
  final Offset linearStart;
  final Offset linearEnd;

  // Brush geometry.
  final List<BrushStroke> strokes;

  // Tonal values, all -1..1 with 0 neutral.
  final double exposure;
  final double contrast;
  final double shadows;
  final double highlights;
  final double saturation;
  final double warmth;
  final double tint;

  /// Global strength of this mask, 0..1 — scales the coverage, not the tonal
  /// values, so dialling it back fades the whole edit like Lightroom's Amount.
  final double amount;

  /// Swaps inside/outside: the adjustments apply everywhere the mask *isn't*.
  final bool inverted;

  bool get hasEffect =>
      amount > 0 &&
      (exposure != 0 ||
          contrast != 0 ||
          shadows != 0 ||
          highlights != 0 ||
          saturation != 0 ||
          warmth != 0 ||
          tint != 0);

  LocalMask copyWith({
    Offset? center,
    double? radius,
    double? radiusY,
    double? angle,
    double? feather,
    Offset? linearStart,
    Offset? linearEnd,
    List<BrushStroke>? strokes,
    double? exposure,
    double? contrast,
    double? shadows,
    double? highlights,
    double? saturation,
    double? warmth,
    double? tint,
    double? amount,
    bool? inverted,
  }) =>
      LocalMask(
        id: id,
        type: type,
        center: center ?? this.center,
        radius: radius ?? this.radius,
        radiusY: radiusY ?? this.radiusY,
        angle: angle ?? this.angle,
        feather: feather ?? this.feather,
        linearStart: linearStart ?? this.linearStart,
        linearEnd: linearEnd ?? this.linearEnd,
        strokes: strokes ?? this.strokes,
        exposure: exposure ?? this.exposure,
        contrast: contrast ?? this.contrast,
        shadows: shadows ?? this.shadows,
        highlights: highlights ?? this.highlights,
        saturation: saturation ?? this.saturation,
        warmth: warmth ?? this.warmth,
        tint: tint ?? this.tint,
        amount: amount ?? this.amount,
        inverted: inverted ?? this.inverted,
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
    if (contrast != 0) m = m.multiply(ColorMatrix.contrast(1.0 + contrast * 0.5));
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
    if (saturation != 0) {
      m = m.multiply(ColorMatrix.saturation(1.0 + saturation));
    }
    if (warmth != 0) m = m.multiply(ColorMatrix.temperature(warmth * 0.8));
    if (tint != 0) m = m.multiply(ColorMatrix.tint(tint * 0.8));
    return m;
  }

  /// Paints this mask's alpha (white = full effect) into [rect], applying
  /// [inverted] and [amount].
  ///
  /// Inversion and amount need their own layer: the shape is rasterized first,
  /// then flipped / dimmed as a whole, otherwise per-shape blending would leak
  /// through (e.g. every brush stroke would invert on its own).
  void paintMaskAlpha(Canvas canvas, Rect rect, Paint paint) {
    if (!inverted && amount >= 1.0) {
      _paintShape(canvas, rect, paint);
      return;
    }

    final blend = paint.blendMode;
    canvas.saveLayer(rect, Paint()..blendMode = blend);
    if (inverted) {
      // Fill, then punch the shape out of it.
      canvas.drawRect(rect, Paint()..color = Colors.white);
      _paintShape(canvas, rect, Paint()..blendMode = BlendMode.dstOut);
    } else {
      _paintShape(canvas, rect, Paint());
    }
    if (amount < 1.0) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: amount.clamp(0.0, 1.0))
          ..blendMode = BlendMode.dstIn,
      );
    }
    canvas.restore();
  }

  void _paintShape(Canvas canvas, Rect rect, Paint paint) {
    final shortest = rect.shortestSide;
    switch (type) {
      case LocalMaskType.radial:
        final c = _toRect(center, rect);
        final rx = math.max(radius * shortest, 0.5);
        final ry = math.max(radiusY * shortest, 0.5);
        // Feather controls where the fade starts: 0 → hard disc, 1 → fade
        // from the very center.
        final inner = (1.0 - feather).clamp(0.0, 0.99);
        // The gradient stays a circle of radius [rx]; its local matrix squashes
        // and rotates it into place. Transforming the shader instead of the
        // canvas keeps the drawn rect exactly [rect], so dstIn still covers the
        // whole layer no matter how extreme the ellipse gets.
        final m = Matrix4.identity()
          ..translateByDouble(c.dx, c.dy, 0, 1)
          ..rotateZ(angle)
          ..scaleByDouble(1.0, ry / rx, 1, 1)
          ..translateByDouble(-c.dx, -c.dy, 0, 1);
        paint.shader = ui.Gradient.radial(
          c,
          rx,
          [Colors.white, Colors.white, Colors.white.withValues(alpha: 0.0)],
          [0.0, inner, 1.0],
          TileMode.clamp,
          m.storage,
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
        // Strokes accumulate in their own layer so an erase stroke removes
        // coverage from the strokes under it rather than from the photo.
        canvas.saveLayer(rect, Paint()..blendMode = paint.blendMode);
        for (final stroke in strokes) {
          if (stroke.points.isEmpty) continue;
          final r = stroke.radius * shortest;
          final strokePaint = Paint()
            ..color = Colors.white.withValues(alpha: stroke.flow.clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..blendMode = stroke.erase ? BlendMode.dstOut : BlendMode.srcOver;
          // Soft edge so brushed areas blend like a feathered Lightroom brush.
          if (stroke.feather > 0.01) {
            strokePaint.maskFilter =
                ui.MaskFilter.blur(ui.BlurStyle.normal, r * stroke.feather);
          }
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
        canvas.restore();
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
    this.healStroke,
    this.healRadius = 0.05,
  });

  final ui.Image image;
  final List<LocalMask> masks;
  final ColorMatrix baseMatrix;
  final LocalMask? overlayMask;

  /// Heal stroke currently under the finger (normalized points). Committed
  /// strokes are already baked into [image], so only this one needs drawing.
  final List<Offset>? healStroke;
  final double healRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    paintLocalMasks(canvas, rect, image, masks, baseMatrix);
    if (overlayMask != null) {
      paintMaskOverlay(canvas, rect, overlayMask!);
    }
    final stroke = healStroke;
    if (stroke != null && stroke.isNotEmpty) {
      paintHealStroke(canvas, rect, stroke, healRadius);
    }
  }

  @override
  bool shouldRepaint(LocalMasksPainter old) =>
      old.image != image ||
      old.masks != masks ||
      old.baseMatrix != baseMatrix ||
      old.overlayMask != overlayMask ||
      old.healStroke != healStroke ||
      old.healRadius != healRadius;
}

/// Live feedback for the remove brush: a soft white trail marking what is
/// about to be repaired.
void paintHealStroke(
  Canvas canvas,
  Rect rect,
  List<Offset> points,
  double radius,
) {
  final r = radius * rect.shortestSide;
  final paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, r * 0.35);

  final path = Path();
  final first = LocalMask._toRect(points.first, rect);
  path.moveTo(first.dx, first.dy);
  if (points.length == 1) {
    path.lineTo(first.dx + 0.1, first.dy + 0.1);
  } else {
    for (final p in points.skip(1)) {
      final abs = LocalMask._toRect(p, rect);
      path.lineTo(abs.dx, abs.dy);
    }
  }
  canvas.drawPath(path, paint);
}

// ── On-canvas handles ──

/// Grab radius around a handle, in logical pixels — sized for a fingertip.
const double kMaskHandleHit = 24.0;

/// How far the rotate handle floats past the shape it turns — wider than
/// [kMaskHandleHit] so it can never steal a grab from the resize handle it
/// sits behind.
const double kMaskRotateGap = 44.0;

/// What a drag on the mask overlay is manipulating. Resolved once at pan start
/// from where the finger landed, so geometry is edited directly on the photo
/// instead of through the tool menu.
enum MaskHandle { move, resize, resizeX, resizeY, rotate, feather, start, end }

/// Pixel-space geometry of a radial mask inside [rect]. The overlay painter and
/// the editor's hit-testing both read it, so a handle is always grabbed exactly
/// where it is drawn.
class RadialHandles {
  RadialHandles(LocalMask mask, this.rect)
      : center = LocalMask._toRect(mask.center, rect),
        rx = math.max(mask.radius * rect.shortestSide, 1.0),
        ry = math.max(mask.radiusY * rect.shortestSide, 1.0),
        angle = mask.angle,
        feather = mask.feather;

  final Rect rect;
  final Offset center;
  final double rx;
  final double ry;
  final double angle;
  final double feather;

  Offset get axisX => Offset(math.cos(angle), math.sin(angle));
  Offset get axisY => Offset(-math.sin(angle), math.cos(angle));

  Offset get right => center + axisX * rx;
  Offset get left => center - axisX * rx;
  Offset get bottom => center + axisY * ry;
  Offset get top => center - axisY * ry;

  /// Quarter-turn offset from [angle] that the rotate handle sticks out along.
  /// Of the sides that keep the handle on the photo the highest one wins, so
  /// the control sits above the mask instead of under the finger holding it.
  double get rotateTurn {
    double? best;
    var bestY = double.infinity;
    for (final turn in _rotateTurns) {
      final p = _rotatePoint(turn);
      if (!rect.contains(p) || p.dy >= bestY) continue;
      bestY = p.dy;
      best = turn;
    }
    return best ?? _rotateTurns.first;
  }

  Offset get rotateAnchor {
    final turn = rotateTurn;
    final a = angle + turn;
    return center + Offset(math.cos(a), math.sin(a)) * _radiusAlong(turn);
  }

  Offset get rotateHandle {
    final p = _rotatePoint(rotateTurn);
    // A mask far bigger than the frame has no side that fits; keep the handle
    // just inside the edge rather than losing it entirely.
    return Offset(
      p.dx.clamp(rect.left + 12, rect.right - 12),
      p.dy.clamp(rect.top + 12, rect.bottom - 12),
    );
  }

  static const List<double> _rotateTurns = [
    -math.pi / 2, // above the ellipse — the preferred spot
    math.pi / 2,
    0.0,
    math.pi,
  ];

  double _radiusAlong(double turn) =>
      (turn.abs() - math.pi / 2).abs() < 0.01 ? ry : rx;

  Offset _rotatePoint(double turn) {
    final a = angle + turn;
    return center +
        Offset(math.cos(a), math.sin(a)) *
            (_radiusAlong(turn) + kMaskRotateGap);
  }

  /// Where the gradient starts falling off — Lightroom's inner ellipse.
  double get innerScale => (1.0 - feather).clamp(0.0, 0.99);

  /// Signed distance of [p] from the centre along [axis].
  double along(Offset p, Offset axis) {
    final v = p - center;
    return v.dx * axis.dx + v.dy * axis.dy;
  }

  /// 1.0 exactly on the ellipse, below inside, above outside.
  double edgeT(Offset p) {
    final v = p - center;
    final lx = v.dx * math.cos(angle) + v.dy * math.sin(angle);
    final ly = -v.dx * math.sin(angle) + v.dy * math.cos(angle);
    return math.sqrt(lx * lx / (rx * rx) + ly * ly / (ry * ry));
  }
}

/// Pixel-space geometry of a linear mask inside [rect].
class LinearHandles {
  LinearHandles(LocalMask mask, this.rect)
      : start = LocalMask._toRect(mask.linearStart, rect),
        end = LocalMask._toRect(mask.linearEnd, rect);

  final Rect rect;
  final Offset start;
  final Offset end;

  Offset get mid => Offset.lerp(start, end, 0.5)!;

  Offset get direction {
    final d = end - start;
    return d.distance < 0.001 ? const Offset(0, 1) : d / d.distance;
  }

  /// Perpendicular to the gradient axis — the direction the guide lines run.
  Offset get normal => Offset(-direction.dy, direction.dx);

  /// How far off the midpoint the rotate handle sits. Always clear of both
  /// outer lines so grabbing one of them never lands on the handle instead.
  double get _rotateReach => math.max(
        kMaskRotateGap * 1.5,
        (end - start).distance / 2 + kMaskRotateGap,
      );

  /// Which way along the gradient axis the rotate handle sits: +1 with
  /// [direction], -1 against it. Prefers whichever end is higher on screen,
  /// and only considers a side that keeps the handle on the photo.
  double get rotateSide {
    final ahead = mid + direction * _rotateReach;
    final behind = mid - direction * _rotateReach;
    final aheadFits = rect.contains(ahead);
    final behindFits = rect.contains(behind);
    if (aheadFits != behindFits) return aheadFits ? 1.0 : -1.0;
    return ahead.dy <= behind.dy ? 1.0 : -1.0;
  }

  /// The handle rides the axis itself, so it points straight along [angle]
  /// (side +1) or straight back down it (side -1).
  double get rotateTurn => rotateSide > 0 ? 0.0 : math.pi;

  Offset get rotateHandle => mid + direction * (_rotateReach * rotateSide);

  /// Where the handle's stem starts: the outer line it floats past, not the
  /// midpoint — a stem drawn all the way from [mid] reads as a fourth line.
  Offset get rotateAnchor => rotateSide > 0 ? end : start;

  /// Perpendicular distance from [p] to the line running through [anchor],
  /// measured along the gradient axis. Grabbing anywhere on a line is far
  /// easier than hitting the dot that sits on it.
  double distanceToLine(Offset p, Offset anchor) {
    final v = p - anchor;
    final dir = direction;
    return (v.dx * dir.dx + v.dy * dir.dy).abs();
  }
}

MaskHandle radialHandleAt(LocalMask mask, Offset p, Rect rect) {
  final h = RadialHandles(mask, rect);
  if ((p - h.rotateHandle).distance <= kMaskHandleHit) {
    return MaskHandle.rotate;
  }
  if ((p - h.right).distance <= kMaskHandleHit ||
      (p - h.left).distance <= kMaskHandleHit) {
    return MaskHandle.resizeX;
  }
  if ((p - h.top).distance <= kMaskHandleHit ||
      (p - h.bottom).distance <= kMaskHandleHit) {
    return MaskHandle.resizeY;
  }
  // Anywhere else on the ring scales both axes together; edgeT is normalized,
  // so scale it back to pixels by the tighter radius before comparing.
  final t = h.edgeT(p);
  final tight = math.min(h.rx, h.ry);
  if ((t - 1.0).abs() * tight <= kMaskHandleHit) return MaskHandle.resize;
  // The inner ellipse is where the fade begins — dragging it is the direct
  // way to feather. Checked after the outer ring so the two never fight when
  // feather is near zero and they sit on top of each other.
  if ((t - h.innerScale).abs() * tight <= kMaskHandleHit) {
    return MaskHandle.feather;
  }
  return MaskHandle.move;
}

/// Whether [p] falls inside the mask's shape — used to pick a mask by tapping
/// the photo. Inversion is ignored on purpose: the shape is what is drawn, so
/// that is what a tap should hit.
bool maskContains(LocalMask mask, Offset p, Rect rect) {
  switch (mask.type) {
    case LocalMaskType.radial:
      return RadialHandles(mask, rect).edgeT(p) <= 1.0;
    case LocalMaskType.linear:
      final h = LinearHandles(mask, rect);
      final span = h.end - h.start;
      if (span.distance < 0.001) return false;
      // Coverage is full at [start] and gone at [end], extending forever
      // behind the start line.
      final t = ((p - h.start).dx * span.dx + (p - h.start).dy * span.dy) /
          span.distanceSquared;
      return t <= 1.0;
    case LocalMaskType.brush:
      final shortest = rect.shortestSide;
      for (final stroke in mask.strokes) {
        if (stroke.erase || stroke.points.isEmpty) continue;
        final r = stroke.radius * shortest;
        for (var i = 0; i < stroke.points.length; i++) {
          final a = LocalMask._toRect(stroke.points[i], rect);
          final b = i + 1 < stroke.points.length
              ? LocalMask._toRect(stroke.points[i + 1], rect)
              : a;
          if (_distanceToSegment(p, a, b) <= r) return true;
        }
      }
      return false;
  }
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lenSq = ab.distanceSquared;
  if (lenSq < 0.0001) return (p - a).distance;
  final t =
      (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lenSq).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

MaskHandle linearHandleAt(LocalMask mask, Offset p, Rect rect) {
  final h = LinearHandles(mask, rect);
  if ((p - h.rotateHandle).distance <= kMaskHandleHit) {
    return MaskHandle.rotate;
  }
  // Three lines, Lightroom-style: the outer two are where the fade starts and
  // ends, the middle one moves the whole gradient. Nearest line wins, and the
  // middle one wins ties so a narrow gradient stays draggable.
  final toMid = h.distanceToLine(p, h.mid);
  final toStart = h.distanceToLine(p, h.start);
  final toEnd = h.distanceToLine(p, h.end);
  final nearest = math.min(toMid, math.min(toStart, toEnd));
  if (nearest > kMaskHandleHit || nearest == toMid) return MaskHandle.move;
  return nearest == toStart ? MaskHandle.start : MaskHandle.end;
}

/// White dot with a dark halo so handles stay readable over bright photos.
void _handleDot(Canvas canvas, Offset p, double r) {
  canvas.drawCircle(
      p, r + 1.5, Paint()..color = Colors.black.withValues(alpha: 0.35));
  canvas.drawCircle(p, r, Paint()..color = Colors.white);
}

void _guideLine(Canvas canvas, Offset a, Offset b, {double alpha = 1.0}) {
  canvas.drawLine(
    a,
    b,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.3 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  canvas.drawLine(
    a,
    b,
    Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

/// Red overlay visualizing the selected mask's coverage (Lightroom-style),
/// plus geometry handles for radial and linear masks.
void paintMaskOverlay(Canvas canvas, Rect rect, LocalMask mask) {
  // Coverage tint: paint the mask alpha in red at reduced opacity.
  canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: 0.45));
  canvas.drawRect(rect, Paint()..color = const Color(0xFFFF3B30));
  mask.paintMaskAlpha(canvas, rect, Paint()..blendMode = BlendMode.dstIn);
  canvas.restore();

  switch (mask.type) {
    case LocalMaskType.radial:
      final h = RadialHandles(mask, rect);
      // The outline is drawn through the canvas transform (an oval can't be
      // rotated any other way); the dots are placed in world space.
      canvas.save();
      canvas.translate(h.center.dx, h.center.dy);
      canvas.rotate(h.angle);
      final oval =
          Rect.fromCenter(center: Offset.zero, width: h.rx * 2, height: h.ry * 2);
      canvas.drawOval(
        oval,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawOval(
        oval,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Inner ellipse = the feather handle. Drawn faint so it reads as the
      // secondary control it is.
      if (h.innerScale < 0.98) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: h.rx * 2 * h.innerScale,
            height: h.ry * 2 * h.innerScale,
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      canvas.restore();

      _guideLine(canvas, h.rotateAnchor, h.rotateHandle);
      _handleDot(canvas, h.center, 4);
      for (final p in [h.left, h.right, h.top, h.bottom]) {
        _handleDot(canvas, p, 6);
      }
      _handleDot(canvas, h.rotateHandle, 7);
      break;
    case LocalMaskType.linear:
      final h = LinearHandles(mask, rect);
      // Three lines perpendicular to the gradient axis: full effect, midpoint,
      // and where the fade runs out. The middle one is the brighter of the
      // three because dragging it moves the whole gradient.
      final len = rect.longestSide;
      for (final p in [h.start, h.end]) {
        _guideLine(canvas, p - h.normal * len, p + h.normal * len, alpha: 0.7);
      }
      _guideLine(canvas, h.mid - h.normal * len, h.mid + h.normal * len);
      _guideLine(canvas, h.rotateAnchor, h.rotateHandle);
      _handleDot(canvas, h.start, 6);
      _handleDot(canvas, h.end, 6);
      _handleDot(canvas, h.mid, 5);
      _handleDot(canvas, h.rotateHandle, 7);
      break;
    case LocalMaskType.brush:
      // Coverage tint alone is the visual — strokes have no handles.
      break;
  }
}
