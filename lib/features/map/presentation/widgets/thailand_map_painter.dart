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
  final Map<String, ui.Image?> provincePhotos;
  final String? selectedProvince;
  final Color baseColor;
  final Color strokeColor;

  ThailandMapPainter({
    required this.provinces,
    required this.provincePhotos,
    this.selectedProvince,
    this.baseColor = const Color(0xFFE0E0E0),
    this.strokeColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (provinces.isEmpty) return;

    // Calculate scaling to fit provinces into the canvas size
    Rect totalBounds = provinces.first.bounds;
    for (var p in provinces.skip(1)) {
      totalBounds = totalBounds.expandToInclude(p.bounds);
    }

    final scaleX = size.width / totalBounds.width;
    final scaleY = size.height / totalBounds.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final offsetX = (size.width - totalBounds.width * scale) / 2 - totalBounds.left * scale;
    final offsetY = (size.height - totalBounds.height * scale) / 2 - totalBounds.top * scale;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    final fillPaint = Paint()..style = ui.PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = strokeColor
      ..strokeWidth = 0.5 / scale;

    for (var province in provinces) {
      final image = provincePhotos[province.name];
      final isSelected = province.name == selectedProvince;

      if (image != null) {
        canvas.save();
        canvas.clipPath(province.path);
        
        // Draw image clipped to province path
        final imgSize = Size(image.width.toDouble(), image.height.toDouble());
        final provinceRect = province.bounds;
        
        final fittedSize = applyBoxFit(BoxFit.cover, imgSize, provinceRect.size);
        final inputRect = Alignment.center.inscribe(fittedSize.source, Offset.zero & imgSize);
        final outputRect = Alignment.center.inscribe(fittedSize.destination, provinceRect);
        
        canvas.drawImageRect(image, inputRect, outputRect, Paint());
        canvas.restore();
      } else {
        fillPaint.color = isSelected ? Colors.blue.withOpacity(0.3) : baseColor;
        canvas.drawPath(province.path, fillPaint);
      }

      // Draw border
      canvas.drawPath(province.path, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThailandMapPainter oldDelegate) {
    return oldDelegate.provincePhotos != provincePhotos || 
           oldDelegate.selectedProvince != selectedProvince;
  }
}

Future<List<ProvinceShape>> loadThailandProvinces() async {
  final String jsonString = await rootBundle.loadString('assets/data/thailand.json');
  final data = json.decode(jsonString);
  final List<ProvinceShape> shapes = [];

  if (data['features'] != null) {
    for (var feature in data['features']) {
      final name = feature['properties']['name'] ?? feature['properties']['NAME_1'] ?? 'Unknown';
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
