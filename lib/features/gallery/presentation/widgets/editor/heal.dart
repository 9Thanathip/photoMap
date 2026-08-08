import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Object removal ("heal") — Lightroom's healing brush, not a blur stamp.
///
/// The user paints over what should go. For each stroke we find the nearest
/// patch of image that *matches the surroundings* and copy it in with a
/// feathered edge, so the repair keeps real texture instead of smearing.
///
/// Geometry is normalized (0..1 on both axes, radius as a fraction of the
/// shortest side) so the on-screen preview and the full-resolution export
/// resolve to the same repair from the same data.
class HealStroke {
  const HealStroke({
    required this.points,
    required this.radius,
    this.sourceShift = Offset.zero,
  });

  final List<Offset> points; // normalized 0..1
  final double radius; // fraction of shortest side

  /// Manual override for where the replacement pixels come from, normalized.
  /// Zero means "search for the best match automatically".
  final Offset sourceShift;

  HealStroke copyWith({
    List<Offset>? points,
    double? radius,
    Offset? sourceShift,
  }) => HealStroke(
    points: points ?? this.points,
    radius: radius ?? this.radius,
    sourceShift: sourceShift ?? this.sourceShift,
  );
}

/// Payload for the isolate: raw RGBA plus the strokes to repair.
class _HealRequest {
  const _HealRequest(this.rgba, this.width, this.height, this.strokes);

  final Uint8List rgba;
  final int width;
  final int height;
  final List<HealStroke> strokes;
}

/// Applies every stroke in [strokes] to [source], returning a repaired image.
/// Returns [source] itself when there is nothing to do, so callers can compare
/// identity to decide whether they own the result.
Future<ui.Image> applyHeal(ui.Image source, List<HealStroke> strokes) async {
  if (strokes.isEmpty) return source;

  final byteData = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return source;

  final healed = await compute(
    _healPixels,
    _HealRequest(
      byteData.buffer.asUint8List(),
      source.width,
      source.height,
      strokes,
    ),
  );

  final buffer = await ui.ImmutableBuffer.fromUint8List(healed);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: source.width,
    height: source.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Pure pixel work — runs on a background isolate.
///
/// Strokes are applied in order against a single working buffer, so a later
/// stroke can sample from an area an earlier one already repaired (which is
/// what you want when clearing several things out of the same region).
Uint8List _healPixels(_HealRequest req) {
  final pixels = Uint8List.fromList(req.rgba);
  final w = req.width;
  final h = req.height;
  final shortest = math.min(w, h).toDouble();

  for (final stroke in req.strokes) {
    if (stroke.points.isEmpty) continue;

    final radiusPx = math.max(2.0, stroke.radius * shortest);
    final all = [for (final p in stroke.points) Offset(p.dx * w, p.dy * h)];

    // Drag samples arrive unevenly (and can be far apart on a fast swipe), so
    // walk the path at a fixed spacing first — otherwise a "segment" could
    // still span half the frame.
    final walked = _resample(all, math.max(1.0, radiusPx * 0.5));

    // Coverage of the *whole* stroke. Segments are healed one at a time, but
    // every segment has to treat the rest of the stroke as off-limits —
    // otherwise a long object gets "repaired" by copying more of itself, since
    // sliding along it is what matches its surroundings best.
    final off = _ObjectMask.fromPath(walked, radiusPx, w, h);

    // Long drags are healed in short segments. One giant patch would need a
    // source patch of the same size somewhere else in the frame — usually there
    // isn't one, and the match quality collapses even when there is.
    for (final pts in _segment(walked, radiusPx * 4)) {
      _healSegment(pixels, w, h, pts, radiusPx, stroke.sourceShift, off);
    }
  }

  return pixels;
}

/// Where the stroke covers the image — the region no repair may sample from.
class _ObjectMask {
  _ObjectMask(this.x0, this.y0, this.w, this.h, this._bits);

  final int x0;
  final int y0;
  final int w;
  final int h;
  final Uint8List _bits;

  factory _ObjectMask.fromPath(
    List<Offset> pts,
    double radiusPx,
    int imageW,
    int imageH,
  ) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    final x0 = (minX - radiusPx).floor().clamp(0, imageW - 1);
    final y0 = (minY - radiusPx).floor().clamp(0, imageH - 1);
    final x1 = (maxX + radiusPx).ceil().clamp(0, imageW - 1);
    final y1 = (maxY + radiusPx).ceil().clamp(0, imageH - 1);
    final w = x1 - x0 + 1;
    final h = y1 - y0 + 1;

    final bits = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final d = _distanceToPolyline(
          Offset((x0 + x).toDouble(), (y0 + y).toDouble()),
          pts,
        );
        if (d < radiusPx) bits[y * w + x] = 1;
      }
    }
    return _ObjectMask(x0, y0, w, h, bits);
  }

  bool covers(int x, int y) {
    final lx = x - x0;
    final ly = y - y0;
    if (lx < 0 || ly < 0 || lx >= w || ly >= h) return false;
    return _bits[ly * w + lx] == 1;
  }
}

/// Walks a polyline emitting a point every [spacing] pixels, so downstream work
/// sees an evenly sampled path regardless of how fast the finger moved.
List<Offset> _resample(List<Offset> pts, double spacing) {
  if (pts.length < 2) return pts;
  final out = <Offset>[pts.first];
  var carry = 0.0;

  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i];
    final b = pts[i + 1];
    final length = (b - a).distance;
    if (length < 1e-6) continue;
    final dir = (b - a) / length;
    var t = spacing - carry;
    while (t <= length) {
      out.add(a + dir * t);
      t += spacing;
    }
    carry = (length - (t - spacing)) % spacing;
  }
  if (out.last != pts.last) out.add(pts.last);
  return out;
}

/// Splits a polyline into runs whose extent stays under [maxExtent], keeping
/// one point of overlap so the repaired segments join without a seam.
List<List<Offset>> _segment(List<Offset> pts, double maxExtent) {
  if (pts.length < 2) return [pts];
  final out = <List<Offset>>[];
  var current = <Offset>[pts.first];
  var minX = pts.first.dx, maxX = pts.first.dx;
  var minY = pts.first.dy, maxY = pts.first.dy;

  for (final p in pts.skip(1)) {
    final nMinX = math.min(minX, p.dx);
    final nMaxX = math.max(maxX, p.dx);
    final nMinY = math.min(minY, p.dy);
    final nMaxY = math.max(maxY, p.dy);
    if (nMaxX - nMinX > maxExtent || nMaxY - nMinY > maxExtent) {
      out.add(current);
      current = [current.last, p];
      minX = math.min(current.first.dx, p.dx);
      maxX = math.max(current.first.dx, p.dx);
      minY = math.min(current.first.dy, p.dy);
      maxY = math.max(current.first.dy, p.dy);
      continue;
    }
    current.add(p);
    minX = nMinX;
    maxX = nMaxX;
    minY = nMinY;
    maxY = nMaxY;
  }
  out.add(current);
  return out;
}

void _healSegment(
  Uint8List pixels,
  int w,
  int h,
  List<Offset> pts,
  double radiusPx,
  Offset sourceShift,
  _ObjectMask off,
) {
  // Patch bounds: the painted area plus a ring of context the matcher scores
  // against.
  final margin = radiusPx * 1.6;
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  final x0 = (minX - margin).floor().clamp(0, w - 1);
  final y0 = (minY - margin).floor().clamp(0, h - 1);
  final x1 = (maxX + margin).ceil().clamp(0, w - 1);
  final y1 = (maxY + margin).ceil().clamp(0, h - 1);
  final pw = x1 - x0 + 1;
  final ph = y1 - y0 + 1;
  if (pw < 3 || ph < 3) return;

  // Coverage: 255 inside the stroke, fading to 0 across the outer 35% of the
  // radius so the seam disappears.
  final alpha = Uint8List(pw * ph);
  final inner = radiusPx * 0.65;
  final fade = math.max(1.0, radiusPx - inner);
  for (var y = 0; y < ph; y++) {
    for (var x = 0; x < pw; x++) {
      final d = _distanceToPolyline(
        Offset((x0 + x).toDouble(), (y0 + y).toDouble()),
        pts,
      );
      if (d >= radiusPx) continue;
      final t = d <= inner ? 1.0 : 1.0 - (d - inner) / fade;
      alpha[y * pw + x] = (t.clamp(0.0, 1.0) * 255).round();
    }
  }

  final offset = sourceShift == Offset.zero
      ? _findSource(pixels, w, h, x0, y0, pw, ph, alpha, radiusPx, off)
      : Offset(sourceShift.dx * w, sourceShift.dy * h);
  if (offset == Offset.zero) return; // nowhere safe to sample from

  final dx = offset.dx.round();
  final dy = offset.dy.round();

  // Snapshot just the source rect first: it can overlap the destination, and
  // reading it live would smear already-written pixels back in.
  final srcPatch = Uint8List(pw * ph * 4);
  for (var y = 0; y < ph; y++) {
    final sy = (y0 + y + dy).clamp(0, h - 1);
    for (var x = 0; x < pw; x++) {
      final sx = (x0 + x + dx).clamp(0, w - 1);
      final si = (sy * w + sx) * 4;
      final pi = (y * pw + x) * 4;
      srcPatch[pi] = pixels[si];
      srcPatch[pi + 1] = pixels[si + 1];
      srcPatch[pi + 2] = pixels[si + 2];
    }
  }

  // Copy the source patch in, weighted by coverage.
  for (var y = 0; y < ph; y++) {
    for (var x = 0; x < pw; x++) {
      final a = alpha[y * pw + x];
      if (a == 0) continue;
      final di = ((y0 + y) * w + (x0 + x)) * 4;
      final pi = (y * pw + x) * 4;
      final t = a / 255.0;
      for (var c = 0; c < 3; c++) {
        pixels[di + c] = (pixels[di + c] * (1 - t) + srcPatch[pi + c] * t)
            .round();
      }
    }
  }
}

/// Picks where to copy from: the offset whose *surroundings* best match the
/// ring of intact pixels around the painted area. Matching on the ring (rather
/// than the hole, which we are about to overwrite) is what makes the patch line
/// up with the background instead of the object being removed.
Offset _findSource(
  Uint8List px,
  int w,
  int h,
  int x0,
  int y0,
  int pw,
  int ph,
  Uint8List alpha,
  double radiusPx,
  _ObjectMask off,
) {
  // Ring samples: pixels inside the patch box that this segment barely touched
  // *and* that no other part of the stroke covers — scoring against the rest of
  // the object would just find more of the object.
  final ring = <int>[];
  final stride = math.max(1, (math.max(pw, ph) / 48).round());
  for (var y = 0; y < ph; y += stride) {
    for (var x = 0; x < pw; x += stride) {
      if (alpha[y * pw + x] >= 24) continue;
      if (off.covers(x0 + x, y0 + y)) continue;
      ring.add(y * pw + x);
    }
  }
  if (ring.length < 12) return Offset.zero;

  // Samples from the hole itself. A candidate has to land these on clean
  // image: matching the ring alone would happily slide along a long object
  // (its surroundings match perfectly) and fill the hole with more object.
  final hole = <int>[];
  for (var y = 0; y < ph; y += stride) {
    for (var x = 0; x < pw; x += stride) {
      if (alpha[y * pw + x] >= 128) hole.add(y * pw + x);
    }
  }

  // Candidate offsets: a few rings of directions around the patch, starting
  // just outside it so the source never overlaps the object.
  final step = math.max(radiusPx * 1.5, math.max(pw, ph) * 0.6);
  var best = Offset.zero;
  var bestScore = double.infinity;

  for (var ringIndex = 1; ringIndex <= 3; ringIndex++) {
    for (var dir = 0; dir < 16; dir++) {
      final angle = dir * math.pi / 8;
      final dx = (math.cos(angle) * step * ringIndex).round();
      final dy = (math.sin(angle) * step * ringIndex).round();
      if (dx == 0 && dy == 0) continue;
      // Skip offsets that would push the patch outside the image.
      if (x0 + dx < 0 ||
          y0 + dy < 0 ||
          x0 + dx + pw >= w ||
          y0 + dy + ph >= h) {
        continue;
      }

      var usable = true;
      for (final idx in hole) {
        if (off.covers(x0 + (idx % pw) + dx, y0 + (idx ~/ pw) + dy)) {
          usable = false;
          break;
        }
      }
      if (!usable) continue;

      var score = 0.0;
      for (final idx in ring) {
        final x = idx % pw;
        final y = idx ~/ pw;
        // Never sample the object itself, at any point along the stroke.
        if (off.covers(x0 + x + dx, y0 + y + dy)) {
          usable = false;
          break;
        }
        final di = ((y0 + y) * w + (x0 + x)) * 4;
        final si = ((y0 + y + dy) * w + (x0 + x + dx)) * 4;
        for (var c = 0; c < 3; c++) {
          final diff = px[di + c] - px[si + c];
          score += diff * diff;
        }
        if (score > bestScore) break; // early out — already worse
      }
      if (usable && score < bestScore) {
        bestScore = score;
        best = Offset(dx.toDouble(), dy.toDouble());
      }
    }
  }
  return best;
}

double _distanceToPolyline(Offset p, List<Offset> pts) {
  if (pts.length == 1) return (p - pts.first).distance;
  var best = double.infinity;
  for (var i = 0; i < pts.length - 1; i++) {
    final d = _distanceToSegment(p, pts[i], pts[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSq = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSq < 1e-6) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSq).clamp(
    0.0,
    1.0,
  );
  return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
}
