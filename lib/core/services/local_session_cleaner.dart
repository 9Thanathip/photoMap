import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/map/data/country_repository.dart';
import '../../features/map/data/cover_photo_repository.dart';
import '../../features/map/presentation/providers/country_provider.dart';
import '../../features/map/presentation/providers/cover_photo_provider.dart';
import '../../features/map/presentation/providers/map_provider.dart';
import '../../features/map/presentation/providers/map_settings_provider.dart';
import '../../features/map/presentation/providers/province_map_provider.dart';
import 'cache_service.dart';

/// Wipes all locally-persisted map data so signing out (or deleting the
/// account) doesn't leak the previous user's map into the next session.
///
/// Covers: cover photos + crops, selected country, map style settings,
/// downloaded country geojson on disk, and the photo/geocoding caches —
/// plus the in-memory providers that hold them.
class LocalSessionCleaner {
  LocalSessionCleaner(this._ref);

  final Ref _ref;

  static const _mapSettingKeys = {
    'map_province_color',
    'map_canvas_color',
    'map_stroke_color',
    'map_stroke_width',
    'current_country_id',
  };

  Future<void> clearMapData() async {
    // Best-effort: a failure here must never block sign-out.
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((k) =>
              k.startsWith('cover_asset_') ||
              k.startsWith('cover_crop_') ||
              _mapSettingKeys.contains(k))
          .toList();
      for (final k in keys) {
        await prefs.remove(k);
      }

      await CoverPhotoRepository().clearAll();
      await CountryRepository().clearAllCache();
      await CacheService().clear();

      _ref.invalidate(countryProvider);
      _ref.invalidate(coverPhotoProvider);
      _ref.invalidate(provinceMapProvider);
      _ref.invalidate(mapProvider);
      _ref.invalidate(mapSettingsProvider);
    } catch (e) {
      debugPrint('LocalSessionCleaner.clearMapData failed: $e');
    }
  }
}

final localSessionCleanerProvider = Provider<LocalSessionCleaner>(
  (ref) => LocalSessionCleaner(ref),
);
