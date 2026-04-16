import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show Rect;

class CoverPhotoRepository {
  static const _assetPrefix = 'cover_asset_';
  static const _cropPrefix = 'cover_crop_';

  Future<String?> getAssetId(String normalizedProvince) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_assetPrefix$normalizedProvince');
  }

  Future<Rect?> getCropRect(String normalizedProvince) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('$_cropPrefix$normalizedProvince');
    if (s == null) return null;
    final parts = s.split(',').map(double.parse).toList();
    if (parts.length != 4) return null;
    return Rect.fromLTRB(parts[0], parts[1], parts[2], parts[3]);
  }

  Future<void> setCover(
      String normalizedProvince, String assetId, Rect cropRect) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_assetPrefix$normalizedProvince', assetId);
    await prefs.setString(
      '$_cropPrefix$normalizedProvince',
      '${cropRect.left},${cropRect.top},${cropRect.right},${cropRect.bottom}',
    );
  }

  Future<Map<String, String>> getAllAssetIds() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_assetPrefix)) {
        final province = key.substring(_assetPrefix.length);
        final assetId = prefs.getString(key);
        if (assetId != null) result[province] = assetId;
      }
    }
    return result;
  }

  Future<Map<String, Rect>> getAllCropRects() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, Rect>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_cropPrefix)) {
        final province = key.substring(_cropPrefix.length);
        final s = prefs.getString(key);
        if (s != null) {
          final parts = s.split(',').map(double.parse).toList();
          if (parts.length == 4) {
            result[province] =
                Rect.fromLTRB(parts[0], parts[1], parts[2], parts[3]);
          }
        }
      }
    }
    return result;
  }
}
