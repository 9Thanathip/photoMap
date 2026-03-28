import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ProvinceBoundary {
  final String name;
  final Path path;

  ProvinceBoundary({required this.name, required this.path});
}

class GeoService {
  List<ProvinceBoundary>? _boundaries;

  /// Loads the GeoJSON file and parses it into paths for point-in-polygon checks.
  Future<void> initialize() async {
    if (_boundaries != null) return;
    
    final String jsonString = await rootBundle.loadString('assets/data/thailand.json');
    final data = json.decode(jsonString);
    final List<ProvinceBoundary> boundaries = [];

    if (data['features'] != null) {
      for (var feature in data['features']) {
        final rawName = feature['properties']['CHA_NE'] ?? 
                        feature['properties']['name'] ?? 
                        feature['properties']['NAME_1'] ?? 'Unknown';
        
        // Normalize name to lowercase and remove spaces/hyphens for consistent matching
        final normalizedName = rawName.toString().replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
        
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
        boundaries.add(ProvinceBoundary(name: normalizedName, path: path));
      }
    }
    _boundaries = boundaries;
  }

  void _addPolygonToPath(Path path, List coordinates) {
    if (coordinates.isEmpty) return;
    // (Long, -Lat) to keep it in a standard coordinate system that plays well with Path.contains
    path.moveTo(coordinates[0][0].toDouble(), -coordinates[0][1].toDouble());
    for (var i = 1; i < coordinates.length; i++) {
      path.lineTo(coordinates[i][0].toDouble(), -coordinates[i][1].toDouble());
    }
    path.close();
  }

  /// Returns the normalized province name for a given lat/lng using the GeoJSON boundaries.
  String? getProvince(double lat, double lng) {
    if (_boundaries == null) return null;
    
    final point = Offset(lng, -lat);
    for (var boundary in _boundaries!) {
      if (boundary.path.contains(point)) {
        return boundary.name;
      }
    }
    return null;
  }
}
