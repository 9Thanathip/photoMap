import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static const String _photoCacheFile = 'photo_metadata_cache.json';
  static const String _geoCacheFile = 'geocoding_cache.json';

  Future<File> _getFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<void> savePhotoMetadata(List<Map<String, dynamic>> data) async {
    try {
      final file = await _getFile(_photoCacheFile);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving photo cache: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> loadPhotoMetadata() async {
    try {
      final file = await _getFile(_photoCacheFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        return List<Map<String, dynamic>>.from(jsonDecode(content));
      }
    } catch (e) {
      print('Error loading photo cache: $e');
    }
    return null;
  }

  Future<void> saveGeoCache(Map<String, dynamic> data) async {
    try {
      final file = await _getFile(_geoCacheFile);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving geo cache: $e');
    }
  }

  Future<Map<String, dynamic>?> loadGeoCache() async {
    try {
      final file = await _getFile(_geoCacheFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        return Map<String, dynamic>.from(jsonDecode(content));
      }
    } catch (e) {
      print('Error loading geo cache: $e');
    }
    return null;
  }
}
