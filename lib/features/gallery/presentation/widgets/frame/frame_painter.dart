import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'camera_logo.dart';
import 'frame_style.dart';

/// Resolved geometry for a frame: the full output canvas plus where the photo
/// sits inside it. Computed once from the photo's pixel size and reused for
/// both the on-screen preview and the full-resolution export so the two match
/// pixel-for-pixel (WYSIWYG).
class FrameGeometry {
  const FrameGeometry({required this.canvasSize, required this.photoRect});

  final Size canvasSize;
  final Rect photoRect;

  /// Proportional sizing unit — all paddings/fonts derive from the photo's
  /// short edge so a phone preview and a 24MP export look identical.
  double get unit => photoRect.shortestSide;
}

/// Computes the frame layout for [style] given the photo's intrinsic pixel
/// [photoSize]. [frameScale] thickens/thins the bar or border (1.0 = default).
FrameGeometry computeFrameGeometry(
  FrameStyle style,
  Size photoSize, {
  double frameScale = 1.0,
}) {
  final w = photoSize.width;
  final h = photoSize.height;
  final short = w < h ? w : h;

  switch (style) {
    case FrameStyle.bottomBar:
      final barH = short * 0.15 * frameScale;
      return FrameGeometry(
        canvasSize: Size(w, h + barH),
        photoRect: Rect.fromLTWH(0, 0, w, h),
      );
    case FrameStyle.fullBorder:
      final margin = short * 0.05 * frameScale;
      final bottom = short * 0.20 * frameScale;
      return FrameGeometry(
        canvasSize: Size(w + margin * 2, h + margin + bottom),
        photoRect: Rect.fromLTWH(margin, margin, w, h),
      );
    case FrameStyle.minimal:
      return FrameGeometry(
        canvasSize: Size(w, h),
        photoRect: Rect.fromLTWH(0, 0, w, h),
      );
  }
}

/// Draws the full framed photo onto [canvas]. Shared by [FramePainter]
/// (preview) and the exporter (`PictureRecorder`). [textScale] multiplies every
/// metadata font size (1.0 = default).
void paintFrame(
  Canvas canvas, {
  required ui.Image photo,
  required FrameData data,
  required FrameStyle style,
  required FrameGeometry geo,
  ui.Image? logo,
  double textScale = 1.0,
}) {
  if (style != FrameStyle.minimal) {
    canvas.drawRect(
      Offset.zero & geo.canvasSize,
      Paint()..color = Colors.white,
    );
  }

  canvas.drawImageRect(
    photo,
    Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
    geo.photoRect,
    Paint()..filterQuality = FilterQuality.high,
  );

  switch (style) {
    case FrameStyle.bottomBar:
      _paintBottomBar(canvas, data, geo, logo, textScale);
      break;
    case FrameStyle.fullBorder:
      _paintFullBorder(canvas, data, geo, textScale);
      break;
    case FrameStyle.minimal:
      _paintMinimal(canvas, data, geo, textScale);
      break;
  }
}

const _ink = Color(0xFF1A1A1A);
const _inkSoft = Color(0xFF8A8A8A);

/// Lays out one line of text, optionally clamped to [maxWidth] with ellipsis.
TextPainter _tp(
  String text, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  double? maxWidth,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  );
  tp.layout(maxWidth: maxWidth ?? double.infinity);
  return tp;
}

// ── Bottom bar (Sony-style) ───────────────────────────────────────────────
// Split into a left half (shooting settings) and a right half (brand + body)
// so the two blocks can never overlap regardless of text length.
void _paintBottomBar(
  Canvas canvas,
  FrameData data,
  FrameGeometry geo,
  ui.Image? logo,
  double ts,
) {
  final barTop = geo.photoRect.bottom;
  final barH = geo.canvasSize.height - barTop;
  final padX = barH * 0.34;
  final cx = barTop + barH / 2;
  final half = geo.canvasSize.width / 2;

  // Left column, clamped to its half.
  final leftMaxW = half - padX * 1.4;
  final settings = _tp(data.settingsLine,
      size: barH * 0.24 * ts,
      color: _ink,
      weight: FontWeight.w700,
      maxWidth: leftMaxW);
  final stamp = _tp(data.timestampLine,
      size: barH * 0.17 * ts,
      color: _inkSoft,
      weight: FontWeight.w500,
      maxWidth: leftMaxW);
  final leftGap = barH * 0.08;
  final leftBlockH = settings.height + stamp.height + leftGap;
  final leftTop = cx - leftBlockH / 2;
  settings.paint(canvas, Offset(padX, leftTop));
  stamp.paint(canvas, Offset(padX, leftTop + settings.height + leftGap));

  final hasBrand = data.cameraLine.isNotEmpty || data.exif.make.isNotEmpty;
  if (!hasBrand) return;

  final rightEdge = geo.canvasSize.width - padX;

  // Reserve space for the logo/wordmark on the right half's left side.
  final logoH = barH * 0.34;
  double logoW = 0;
  if (logo != null) {
    logoW = logoH * (logo.width / logo.height);
  }
  final wordmark = logo == null && data.exif.make.isNotEmpty
      ? _tp(CameraLogo.wordmark(data.exif.make),
          size: barH * 0.26 * ts,
          color: _ink,
          weight: FontWeight.w800,
          letterSpacing: 1,
          maxWidth: half * 0.5)
      : null;
  final brandW = logo != null ? logoW : (wordmark?.width ?? 0);
  final brandGap = brandW > 0 ? padX * 0.6 : 0.0;

  // Right text column gets whatever's left of the right half.
  final rightMaxW = half - padX * 1.4 - brandW - brandGap;
  final camera = _tp(data.cameraLine,
      size: barH * 0.22 * ts,
      color: _ink,
      weight: FontWeight.w700,
      maxWidth: rightMaxW);
  final lens = _tp(data.lensLine,
      size: barH * 0.16 * ts,
      color: _inkSoft,
      weight: FontWeight.w500,
      maxWidth: rightMaxW);
  final rightGap = barH * 0.06;
  final rightBlockH = camera.height + lens.height + rightGap;
  final rightTop = cx - rightBlockH / 2;
  camera.paint(canvas, Offset(rightEdge - camera.width, rightTop));
  lens.paint(canvas,
      Offset(rightEdge - lens.width, rightTop + camera.height + rightGap));

  final textLeft =
      rightEdge - (camera.width > lens.width ? camera.width : lens.width);
  final brandRight = textLeft - brandGap;

  if (logo != null) {
    final dst =
        Rect.fromLTWH(brandRight - logoW, cx - logoH / 2, logoW, logoH);
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  } else if (wordmark != null) {
    wordmark.paint(
        canvas, Offset(brandRight - wordmark.width, cx - wordmark.height / 2));
  }
}

// ── Full border (polaroid) ────────────────────────────────────────────────
void _paintFullBorder(
  Canvas canvas,
  FrameData data,
  FrameGeometry geo,
  double ts,
) {
  final areaTop = geo.photoRect.bottom;
  final areaH = geo.canvasSize.height - areaTop;
  final centerY = areaTop + areaH / 2;
  final w = geo.canvasSize.width;
  final maxW = w * 0.9;

  final camera = _tp(data.cameraLine,
      size: areaH * 0.20 * ts,
      color: _ink,
      weight: FontWeight.w700,
      maxWidth: maxW);
  final settings = _tp(data.settingsLine,
      size: areaH * 0.15 * ts,
      color: _inkSoft,
      weight: FontWeight.w500,
      maxWidth: maxW);
  final gap = areaH * 0.08;
  final blockH = camera.height + settings.height + gap;
  final top = centerY - blockH / 2;

  camera.paint(canvas, Offset((w - camera.width) / 2, top));
  settings.paint(
      canvas, Offset((w - settings.width) / 2, top + camera.height + gap));
}

// ── Minimal overlay ───────────────────────────────────────────────────────
void _paintMinimal(
  Canvas canvas,
  FrameData data,
  FrameGeometry geo,
  double ts,
) {
  final r = geo.photoRect;
  final scrimH = r.height * 0.22;
  canvas.drawRect(
    Rect.fromLTWH(r.left, r.bottom - scrimH, r.width, scrimH),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, r.bottom - scrimH),
        Offset(0, r.bottom),
        [const Color(0x00000000), const Color(0x99000000)],
      ),
  );

  final pad = geo.unit * 0.04;
  final maxW = r.width * 0.5 - pad * 1.5;
  final settings = _tp(data.settingsLine,
      size: geo.unit * 0.03 * ts,
      color: Colors.white,
      weight: FontWeight.w600,
      maxWidth: maxW);
  final camera = _tp(data.cameraLine,
      size: geo.unit * 0.03 * ts,
      color: Colors.white,
      weight: FontWeight.w600,
      maxWidth: maxW);
  final baseline = r.bottom - pad - settings.height;
  settings.paint(canvas, Offset(r.left + pad, baseline));
  camera.paint(canvas, Offset(r.right - pad - camera.width, baseline));
}

/// CustomPainter wrapper for the live preview. Paints the framed photo scaled
/// to fit the given widget box.
class FramePainter extends CustomPainter {
  FramePainter({
    required this.photo,
    required this.data,
    required this.style,
    required this.geo,
    this.logo,
    this.textScale = 1.0,
  });

  final ui.Image photo;
  final FrameData data;
  final FrameStyle style;
  final FrameGeometry geo;
  final ui.Image? logo;
  final double textScale;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / geo.canvasSize.width;
    canvas.save();
    canvas.scale(scale);
    paintFrame(canvas,
        photo: photo,
        data: data,
        style: style,
        geo: geo,
        logo: logo,
        textScale: textScale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FramePainter old) =>
      old.photo != photo ||
      old.data != data ||
      old.style != style ||
      old.logo != logo ||
      old.textScale != textScale ||
      old.geo.canvasSize != geo.canvasSize;
}
