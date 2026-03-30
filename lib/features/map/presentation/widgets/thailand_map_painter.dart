import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class ProvinceShape {
  final String name;
  final Path path;
  final Rect bounds;

  ProvinceShape({required this.name, required this.path}) : bounds = path.getBounds();
}

class ThailandMapPainter extends CustomPainter {
  final List<ProvinceShape> provinces;
  final Path? combinedPath; // Cached combined path for shadows
  final Map<String, ui.Image?> provincePhotos;
  final Map<String, DateTime> imageLoadTimes;
  final DateTime currentTime;
  final DateTime openTime;
  final String? selectedProvince;
  final Color baseColor;
  final Color strokeColor;

  final Color? canvasColor;

  ThailandMapPainter({
    required this.provinces,
    this.combinedPath,
    required this.provincePhotos,
    required this.imageLoadTimes,
    required this.currentTime,
    required this.openTime,
    this.selectedProvince,
    this.baseColor = const Color(0xFFE0E0E0),
    this.strokeColor = Colors.white,
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

    final offsetX = (size.width - totalBounds.width * scale) / 2 - totalBounds.left * scale;
    final offsetY = (size.height - totalBounds.height * scale) / 2 - totalBounds.top * scale;

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
      ..strokeWidth = 0.5 / scale;

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
        final animStartTime = imageLoadTime.isAfter(openTime) ? imageLoadTime : openTime;
        final diff = currentTime.difference(animStartTime).inMilliseconds;
        final opacity = (diff / 750).clamp(0.0, 1.0);

        if (opacity > 0) {
          canvas.save();
          canvas.clipPath(province.path);

          final imagePaint = Paint()
            ..filterQuality = ui.FilterQuality.low
            ..color = Colors.white.withValues(alpha: opacity);

          final imgSize = Size(image.width.toDouble(), image.height.toDouble());
          final provinceRect = province.bounds;

          final fittedSize = applyBoxFit(BoxFit.cover, imgSize, provinceRect.size);
          final inputRect = Alignment.center.inscribe(fittedSize.source, Offset.zero & imgSize);
          final outputRect = Alignment.center.inscribe(fittedSize.destination, provinceRect);

          canvas.drawImageRect(image, inputRect, outputRect, imagePaint);
          canvas.restore();
        }
      }

      // Draw border
      canvas.drawPath(province.path, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThailandMapPainter oldDelegate) {
    return oldDelegate.provincePhotos != provincePhotos ||
           oldDelegate.selectedProvince != selectedProvince ||
           oldDelegate.currentTime != currentTime ||
           oldDelegate.openTime != openTime ||
           oldDelegate.baseColor != baseColor ||
           oldDelegate.canvasColor != canvasColor;
  }
}

Future<List<ProvinceShape>> loadThailandProvinces() async {
  final String jsonString = await rootBundle.loadString('assets/data/thailand.json');
  final data = json.decode(jsonString);
  final List<ProvinceShape> shapes = [];

  if (data['features'] != null) {
    for (var feature in data['features']) {
      final rawName = feature['properties']['CHA_NE'] ?? feature['properties']['name'] ?? feature['properties']['NAME_1'] ?? 'Unknown';
      // Normalize name by removing spaces, hyphens and converting to lowercase
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
  path.moveTo(coordinates[0][0].toDouble(), -coordinates[0][1].toDouble()); // Note the negative Y for screen coords
  for (var i = 1; i < coordinates.length; i++) {
    path.lineTo(coordinates[i][0].toDouble(), -coordinates[i][1].toDouble());
  }
  path.close();
}
