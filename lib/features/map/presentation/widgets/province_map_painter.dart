import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class DistrictShape {
  final String name;
  final Path path;
  final Rect bounds;

  DistrictShape({required this.name, required this.path})
    : bounds = path.getBounds();
}

class ProvinceMapPainter extends CustomPainter {
  final List<DistrictShape> districts;
  final Path? combinedPath;
  final Map<String, ui.Image?> districtPhotos;
  final Map<String, DateTime> imageLoadTimes;
  final DateTime currentTime;
  final DateTime openTime;
  final String? selectedDistrict;
  final Color baseColor;
  final Color strokeColor;
  final Color? canvasColor;

  ProvinceMapPainter({
    required this.districts,
    this.combinedPath,
    required this.districtPhotos,
    required this.imageLoadTimes,
    required this.currentTime,
    required this.openTime,
    this.selectedDistrict,
    this.baseColor = const Color(0xFFE0E0E0),
    this.strokeColor = Colors.white,
    this.canvasColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (districts.isEmpty) return;

    if (canvasColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = canvasColor!);
    }

    Rect totalBounds = districts.first.bounds;
    for (var d in districts.skip(1)) {
      totalBounds = totalBounds.expandToInclude(d.bounds);
    }

    final scaleX = size.width / totalBounds.width;
    final scaleY = size.height / totalBounds.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;

    final offsetX =
        (size.width - totalBounds.width * scale) / 2 - totalBounds.left * scale;
    final offsetY =
        (size.height - totalBounds.height * scale) / 2 - totalBounds.top * scale;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    final Rect visibleRect = canvas.getLocalClipBounds();

    // Shadow
    if (combinedPath != null && scale < 10.0) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 / scale);

      canvas.save();
      canvas.translate(0, 2.0 / scale);
      canvas.drawPath(combinedPath!, shadowPaint);
      canvas.restore();
    }

    final fillPaint = Paint()..style = ui.PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = strokeColor
      ..strokeWidth = 0.8 / scale;

    for (var district in districts) {
      if (!visibleRect.overlaps(district.bounds)) continue;

      final image = districtPhotos[district.name];
      final isSelected = district.name == selectedDistrict;

      fillPaint.color = isSelected
          ? Colors.blue.withValues(alpha: 0.3)
          : baseColor;
      canvas.drawPath(district.path, fillPaint);

      if (image != null) {
        final imageLoadTime = imageLoadTimes[district.name] ?? openTime;
        final animStartTime = imageLoadTime.isAfter(openTime)
            ? imageLoadTime
            : openTime;
        final diff = currentTime.difference(animStartTime).inMilliseconds;
        final opacity = (diff / 750).clamp(0.0, 1.0);

        if (opacity > 0) {
          canvas.save();
          canvas.clipPath(district.path);

          final imagePaint = Paint()
            ..filterQuality = ui.FilterQuality.low
            ..color = Colors.white.withValues(alpha: opacity);

          final imgSize = Size(image.width.toDouble(), image.height.toDouble());
          final districtRect = district.bounds;

          final fittedSize = applyBoxFit(
            BoxFit.cover,
            imgSize,
            districtRect.size,
          );
          final inputRect = Alignment.center.inscribe(
            fittedSize.source,
            Offset.zero & imgSize,
          );
          final outputRect = Alignment.center.inscribe(
            fittedSize.destination,
            districtRect,
          );

          canvas.drawImageRect(image, inputRect, outputRect, imagePaint);
          canvas.restore();
        }
      }

      canvas.drawPath(district.path, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ProvinceMapPainter oldDelegate) {
    return oldDelegate.districtPhotos != districtPhotos ||
        oldDelegate.selectedDistrict != selectedDistrict ||
        oldDelegate.currentTime != currentTime ||
        oldDelegate.openTime != openTime ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.canvasColor != canvasColor;
  }
}
