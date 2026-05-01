import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class ProvinceShape {
  final String name;
  final Path path;
  final Rect bounds;

  ProvinceShape({required this.name, required this.path})
    : bounds = path.getBounds();
}

class ThailandMapPainter extends CustomPainter {
  final List<ProvinceShape> provinces;
  final Path? combinedPath;
  final Map<String, ui.Image?> provincePhotos;
  final Map<String, DateTime> imageLoadTimes;
  final Map<String, ui.Rect> cropRects; // normalized 0-1 crop per province
  final DateTime currentTime;
  final DateTime openTime;
  final String? selectedProvince;
  final Color baseColor;
  final Color strokeColor;
  final double strokeWidth;
  final Color? canvasColor;

  ThailandMapPainter({
    required this.provinces,
    this.combinedPath,
    required this.provincePhotos,
    required this.imageLoadTimes,
    this.cropRects = const {},
    required this.currentTime,
    required this.openTime,
    this.selectedProvince,
    this.baseColor = const Color(0xFFE0E0E0),
    this.strokeColor = Colors.white,
    this.strokeWidth = 0.8,
    this.canvasColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (provinces.isEmpty) return;

    // Fill canvas background (used when exporting and for dark themes)
    if (canvasColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = canvasColor!);
    }

    // Calculate scaling to fit provinces into the canvas size
    Rect totalBounds = provinces.first.bounds;
    for (var p in provinces.skip(1)) {
      totalBounds = totalBounds.expandToInclude(p.bounds);
    }

    final scaleX = size.width / totalBounds.width;
    final scaleY = size.height / totalBounds.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.80;

    final offsetX =
        (size.width - totalBounds.width * scale) / 2 - totalBounds.left * scale;
    final offsetY =
        (size.height - totalBounds.height * scale) / 2 -
        totalBounds.top * scale;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    // Get the visible area in the current (province) coordinate system.
    // This allows us to skip drawing provinces that are off-screen.
    final Rect visibleRect = canvas.getLocalClipBounds();

    // 1. Draw One Unified Soft Shadow (Pre-calculated for performance)
    // Only draw shadow at low zoom levels (scale < 3.0) to save GPU memory.
    // At high zoom, the country-wide shadow is irrelevant and prone to crashing GPUs.
    if (combinedPath != null && scale < 2.5) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 / scale);

      canvas.save();
      canvas.translate(0, 3.0 / scale);
      canvas.drawPath(combinedPath!, shadowPaint);
      canvas.restore();
    }

    final fillPaint = Paint()..style = ui.PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = strokeColor
      ..strokeWidth = strokeWidth / scale;

    for (var province in provinces) {
      // Frustum Culling: Skip if province is outside visible area
      if (!visibleRect.overlaps(province.bounds)) continue;

      final image = provincePhotos[province.name];
      final isSelected = province.name == selectedProvince;

      // Always draw base fill so the province shape is visible during fade-in
      fillPaint.color = isSelected ? Colors.blue.withValues(alpha: 0.3) : baseColor;
      canvas.drawPath(province.path, fillPaint);

      if (image != null) {
        final imageLoadTime = imageLoadTimes[province.name] ?? openTime;
        final animStartTime = imageLoadTime.isAfter(openTime)
            ? imageLoadTime
            : openTime;
        final diff = currentTime.difference(animStartTime).inMilliseconds;
        final opacity = (diff / 750).clamp(0.0, 1.0);

        if (opacity > 0) {
          canvas.save();
          canvas.clipPath(province.path);

          final imagePaint = Paint()
            ..filterQuality = ui.FilterQuality.low
            ..color = Colors.white.withValues(alpha: opacity);

          final imgW = image.width.toDouble();
          final imgH = image.height.toDouble();
          final imgSize = Size(imgW, imgH);
          final provinceRect = province.bounds;

          ui.Rect inputRect;
          ui.Rect outputRect;
          final cropNorm = cropRects[province.name];
          if (cropNorm != null) {
            // Crop rect in pixel space
            final cropPx = ui.Rect.fromLTRB(
              cropNorm.left * imgW,
              cropNorm.top * imgH,
              cropNorm.right * imgW,
              cropNorm.bottom * imgH,
            );
            // Cover-fit the crop region into the province bounds to avoid stretching
            final fitted = applyBoxFit(BoxFit.cover, cropPx.size, provinceRect.size);
            inputRect = Alignment.center.inscribe(fitted.source, cropPx);
            outputRect = Alignment.center.inscribe(fitted.destination, provinceRect);
          } else {
            final fittedSize = applyBoxFit(BoxFit.cover, imgSize, provinceRect.size);
            inputRect = Alignment.center.inscribe(fittedSize.source, Offset.zero & imgSize);
            outputRect = Alignment.center.inscribe(fittedSize.destination, provinceRect);
          }

          canvas.drawImageRect(image, inputRect, outputRect, imagePaint);
          canvas.restore();
        }
      }

      // Draw border
      canvas.drawPath(province.path, strokePaint);
    }

    canvas.restore();

    // Draw "T H A I L A N D" text at the bottom center
    // This is drawn AFTER canvas.restore so it stays fixed and centered on the final export
    // final isDarkBackground =
    //     canvasColor != null &&
    //     ThemeData.estimateBrightnessForColor(canvasColor!) == Brightness.dark;

    // final textPainter = TextPainter(
    //   text: TextSpan(
    //     text: 'T  H  A  I  L  A  N  D',
    //     style: TextStyle(
    //       color: isDarkBackground
    //           ? Colors.white.withOpacity(0.4)
    //           : Colors.black.withOpacity(0.4),
    //       fontSize: 16,
    //       fontWeight: FontWeight.w400,
    //       letterSpacing: 4,
    //     ),
    //   ),
    //   textDirection: TextDirection.ltr,
    // )..layout();

    // textPainter.paint(
    //   canvas,
    //   Offset(
    //     (size.width - textPainter.width) / 2,
    //     size.height - textPainter.height - 60, // Positioned near the bottom
    //   ),
    // );
  }

  @override
  bool shouldRepaint(covariant ThailandMapPainter oldDelegate) {
    return oldDelegate.provincePhotos != provincePhotos ||
        oldDelegate.cropRects != cropRects ||
        oldDelegate.selectedProvince != selectedProvince ||
        oldDelegate.currentTime != currentTime ||
        oldDelegate.openTime != openTime ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.canvasColor != canvasColor;
  }
}

Future<List<ProvinceShape>> loadThailandProvinces() async {
  final String jsonString = await rootBundle.loadString(
    'assets/data/thailand.json',
  );
  return parseProvincesFromGeoJson(jsonString);
}

/// Parse GeoJSON FeatureCollection into province shapes.
/// Supports asset shape (CHA_NE/name) and GADM shape (NAME_1).
List<ProvinceShape> parseProvincesFromGeoJson(String jsonString) {
  final data = json.decode(jsonString);
  final List<ProvinceShape> shapes = [];

  if (data['features'] != null) {
    for (var feature in data['features']) {
      final rawName =
          feature['properties']['CHA_NE'] ??
          feature['properties']['name'] ??
          feature['properties']['NAME_1'] ??
          'Unknown';
      final name = rawName.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
      final geometry = feature['geometry'];
      final type = geometry['type'];
      final coordinates = geometry['coordinates'];

      final path = Path();
      if (type == 'Polygon') {
        _addPolygonToPath(path, coordinates[0]);
      } else if (type == 'MultiPolygon') {
        for (var polygon in coordinates) {
          _addPolygonToPath(path, polygon[0]);
        }
      }
      shapes.add(ProvinceShape(name: name, path: path));
    }
  }
  return shapes;
}

void _addPolygonToPath(Path path, List coordinates) {
  if (coordinates.isEmpty) return;
  path.moveTo(
    coordinates[0][0].toDouble(),
    -coordinates[0][1].toDouble(),
  ); // Note the negative Y for screen coords
  for (var i = 1; i < coordinates.length; i++) {
    path.lineTo(coordinates[i][0].toDouble(), -coordinates[i][1].toDouble());
  }
  path.close();
}
