import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Hard stop on how far into a photo a cell can be zoomed. The source is a
/// 1280px thumbnail, so past this it is visibly soft.
const double kCellMaxZoom = 6.0;

/// Residual turn that snaps back to level, ~2°. Straightening a horizon by hand
/// otherwise almost never lands exactly on zero.
const double kCellStraightenSnap = 0.035;

/// How a photo sits inside its collage cell: a zoom on top of the cover fit, a
/// turn, and a pan.
///
/// Stored relative to the cell rather than in pixels, because the same value
/// has to paint into a ~120pt preview cell *and* a ~1200px export cell. The
/// export canvas is a uniformly scaled copy of the preview — same grid, same
/// ratio, gap is a fraction of the short side — so one normalised number is
/// correct for both, and what the user framed is what gets saved.
@immutable
class CellTransform {
  const CellTransform({
    this.scale = 1.0,
    this.rotation = 0.0,
    this.offset = Offset.zero,
  });

  /// Zoom on top of the scale that just covers the cell. 1.0 = tightest fit.
  final double scale;

  /// Clockwise turn of the photo, in radians.
  final double rotation;

  /// Pan of the photo's centre away from the cell's, in cell widths, along the
  /// **cell's** axes rather than the photo's — so dragging right moves the
  /// photo right however far it has been turned.
  final Offset offset;

  bool get isIdentity =>
      scale == 1.0 && rotation == 0.0 && offset == Offset.zero;

  CellTransform copyWith({double? scale, double? rotation, Offset? offset}) =>
      CellTransform(
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        offset: offset ?? this.offset,
      );

  @override
  bool operator ==(Object other) =>
      other is CellTransform &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, rotation, offset);
}

/// Smallest scale at which [image] still covers every corner of [cell] once
/// turned by [rotation].
///
/// A turned photo has to be bigger to keep the background out: seen from the
/// photo's own frame the cell grows to `w·|cos| + h·|sin|` by
/// `w·|sin| + h·|cos|`, and the photo must span both.
double cellCoverScale(Size image, Size cell, double rotation) {
  if (image.isEmpty || cell.isEmpty) return 1.0;
  final c = math.cos(rotation).abs();
  final s = math.sin(rotation).abs();
  final needW = cell.width * c + cell.height * s;
  final needH = cell.width * s + cell.height * c;
  return math.max(needW / image.width, needH / image.height);
}

/// [t]'s pan pulled back to the furthest it can travel before a gap opens at a
/// cell edge, in the same cell-width units as [CellTransform.offset].
///
/// Independent of how big the cell is drawn — only its aspect matters — which
/// is what lets the export reproduce the preview exactly.
Offset clampCellPan(
  CellTransform t, {
  required Size image,
  required Size cell,
}) {
  if (image.isEmpty || cell.isEmpty) return Offset.zero;
  final scale = cellCoverScale(image, cell, t.rotation) * t.scale;
  final c = math.cos(t.rotation).abs();
  final s = math.sin(t.rotation).abs();
  // Slack is whatever the photo overhangs the cell by, measured along the
  // photo's own axes.
  final slackX = math.max(
      0.0, (image.width * scale - (cell.width * c + cell.height * s)) / 2);
  final slackY = math.max(
      0.0, (image.height * scale - (cell.width * s + cell.height * c)) / 2);

  // So the pan has to be taken into that frame, clipped there, and brought
  // back — clipping x and y as they are would let a turned photo slide off a
  // corner.
  final px = t.offset * cell.width;
  final rc = math.cos(t.rotation);
  final rs = math.sin(t.rotation);
  final ax = (px.dx * rc + px.dy * rs).clamp(-slackX, slackX);
  final ay = (-px.dx * rs + px.dy * rc).clamp(-slackY, slackY);
  return Offset(ax * rc - ay * rs, ax * rs + ay * rc) / cell.width;
}

/// Draws [img] into [cell] under [t], cropped to the cell.
///
/// The pan is clamped here rather than trusted, so a transform captured against
/// one cell shape still paints without leaking background after the grid is
/// resized underneath it.
void drawCellImage(
  ui.Canvas canvas,
  ui.Image img,
  Rect cell,
  CellTransform t, {
  FilterQuality quality = FilterQuality.high,
}) {
  final image = Size(img.width.toDouble(), img.height.toDouble());
  if (image.isEmpty || cell.isEmpty) return;
  final scale = cellCoverScale(image, cell.size, t.rotation) * t.scale;
  final pan = clampCellPan(t, image: image, cell: cell.size) * cell.width;

  canvas.save();
  canvas.clipRect(cell);
  canvas.translate(cell.center.dx + pan.dx, cell.center.dy + pan.dy);
  if (t.rotation != 0) {
    canvas.rotate(t.rotation);
  }
  canvas.drawImageRect(
    img,
    Offset.zero & image,
    Rect.fromCenter(
      center: Offset.zero,
      width: image.width * scale,
      height: image.height * scale,
    ),
    Paint()..filterQuality = quality,
  );
  canvas.restore();
}
