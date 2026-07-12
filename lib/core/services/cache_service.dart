import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
      debugPrint('Error saving photo cache: $e');
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
      debugPrint('Error loading photo cache: $e');
    }
    return null;
  }

  Future<void> saveGeoCache(Map<String, dynamic> data) async {
    try {
      final file = await _getFile(_geoCacheFile);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving geo cache: $e');
    }
  }

  /// Deletes the on-disk photo metadata + geocoding caches. Used on
  /// sign-out so a new account doesn't inherit the previous map state.
  Future<void> clear() async {
    for (final name in const [_photoCacheFile, _geoCacheFile]) {
      try {
        final file = await _getFile(name);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Error clearing cache $name: $e');
      }
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
      debugPrint('Error loading geo cache: $e');
    }
    return null;
  }
}
