import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Uniform [rows]×[cols] grid layout with an even [gap] between and around the
/// cells. Cell index is `row * cols + col`.
class CollageGrid {
  const CollageGrid(this.rows, this.cols);
  final int rows;
  final int cols;

  int get count => rows * cols;

  /// The rectangle for cell [index] inside [area], accounting for [gap].
  Rect cellRect(int index, Rect area, double gap) {
    final r = index ~/ cols;
    final c = index % cols;
    final cellW = (area.width - gap * (cols + 1)) / cols;
    final cellH = (area.height - gap * (rows + 1)) / rows;
    return Rect.fromLTWH(
      area.left + gap + c * (cellW + gap),
      area.top + gap + r * (cellH + gap),
      cellW,
      cellH,
    );
  }

  /// Cell index at [point] within [area], or null if in a gap/outside.
  int? indexAt(Offset point, Rect area, double gap) {
    for (var i = 0; i < count; i++) {
      if (cellRect(i, area, gap).contains(point)) return i;
    }
    return null;
  }
}

/// Draws the grid collage: background fill, then each cell's photo cover-fitted
/// and centre-cropped. Shared by the preview [CollagePainter] and the exporter.
/// [selected] highlights a cell (preview only); [placeholder] fills empty cells
/// (preview only — export passes null).
void paintCollage(
  Canvas canvas,
  Rect rect, {
  required CollageGrid grid,
  required double gap,
  required Color background,
  required Map<int, ui.Image> images,
  int? selected,
  Color? placeholder,
}) {
  canvas.drawRect(rect, Paint()..color = background);

  for (var i = 0; i < grid.count; i++) {
    final cell = grid.cellRect(i, rect, gap);
    final img = images[i];
    if (img != null) {
      _drawCover(canvas, img, cell);
    } else if (placeholder != null) {
      canvas.drawRect(cell, Paint()..color = placeholder);
    }
    if (selected == i) {
      canvas.drawRect(
        cell.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
    }
  }
}

/// Draws [img] to fill [dst], preserving aspect via a centred source crop.
void _drawCover(Canvas canvas, ui.Image img, Rect dst) {
  final iw = img.width.toDouble();
  final ih = img.height.toDouble();
  final srcAR = iw / ih;
  final dstAR = dst.width / dst.height;

  Rect src;
  if (srcAR > dstAR) {
    final cropW = ih * dstAR;
    src = Rect.fromLTWH((iw - cropW) / 2, 0, cropW, ih);
  } else {
    final cropH = iw / dstAR;
    src = Rect.fromLTWH(0, (ih - cropH) / 2, iw, cropH);
  }

  canvas.save();
  canvas.clipRect(dst);
  canvas.drawImageRect(
      img, src, dst, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();
}

/// CustomPainter wrapper for the live preview.
class CollagePainter extends CustomPainter {
  CollagePainter({
    required this.grid,
    required this.gap,
    required this.background,
    required this.images,
    required this.revision,
    this.selected,
    this.placeholder,
    this.dragImage,
    this.dragCenter,
    this.dragTarget,
  });

  final CollageGrid grid;
  final double gap;
  final Color background;
  final Map<int, ui.Image> images;
  final int? selected;
  final Color? placeholder;

  /// Drag-to-swap overlay (preview only): the lifted cell's image floating at
  /// [dragCenter], plus a highlight ring on the [dragTarget] cell.
  final ui.Image? dragImage;
  final Offset? dragCenter;
  final int? dragTarget;

  /// Bumped by the screen whenever a cell's photo changes, so the painter
  /// repaints (the [images] map is mutated in place).
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    paintCollage(
      canvas,
      rect,
      grid: grid,
      gap: gap,
      background: background,
      images: images,
      selected: selected,
      placeholder: placeholder,
    );

    if (dragTarget != null) {
      canvas.drawRect(
        grid.cellRect(dragTarget!, rect, gap).deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF4C9AFF),
      );
    }
    if (dragImage != null && dragCenter != null) {
      final s = size.shortestSide * 0.22;
      final dst = Rect.fromCenter(center: dragCenter!, width: s, height: s);
      canvas.save();
      canvas.clipRRect(
          RRect.fromRectAndRadius(dst, const Radius.circular(8)));
      _drawCover(canvas, dragImage!, dst);
      canvas.restore();
      canvas.drawRRect(
        RRect.fromRectAndRadius(dst, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(CollagePainter old) =>
      old.revision != revision ||
      old.grid.rows != grid.rows ||
      old.grid.cols != grid.cols ||
      old.gap != gap ||
      old.background != background ||
      old.selected != selected ||
      old.dragCenter != dragCenter ||
      old.dragTarget != dragTarget;
}
