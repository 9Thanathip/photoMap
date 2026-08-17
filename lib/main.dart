import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/core/services/thumb_cache.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_map/features/map/data/country_repository.dart';
import 'package:photo_map/features/map/domain/models/country.dart';
import 'package:photo_map/features/map/presentation/providers/country_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter's 100 MB default holds only ~150 grid tiles, so scrolling a real
  // library evicts constantly and every trip back up the list re-runs the
  // platform thumbnail request — which on iOS encodes on the main thread.
  // Flutter still drops the whole cache on memory pressure, so this is a
  // ceiling, not a reservation.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;

  // The count limit binds long before the byte limit once the small previews
  // are in there too: a 128px preview is 64 KB decoded against a tile's 640 KB,
  // so a thousand entries is a few hundred tiles and nothing left over. Raising
  // it lets thousands of previews stay resident — which is what makes a tile
  // able to paint the moment it is built — while bytes stay capped above.
  PaintingBinding.instance.imageCache.maximumSize = 3000;

  // Resolve the thumbnail cache directory up front. ThumbCache.pathFor is
  // synchronous and reports "not ready" rather than waiting, so without this
  // the first screenful of tiles would all miss and go to the platform.
  unawaited(ThumbCache.instance.warmUp());

  String? initialCountryId;
  List<Country> cachedCountries = const [];

  try {
    await Firebase.initializeApp();

    // Load initial country ID as early as possible
    final prefs = await SharedPreferences.getInstance();
    initialCountryId = prefs.getString('current_country_id');

    // Pre-load cached country metadata so the map can render immediately
    // without waiting for firestore.
    try {
      cachedCountries = await CountryRepository().loadCachedCountries();
    } catch (e) {
      debugPrint('Cached countries load failed: $e');
    }

    // Configure Firestore for both default and named instances
    final firestoreSettings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    FirebaseFirestore.instance.settings = firestoreSettings;
    
    // Also apply to the 'countries' database instance if it exists
    try {
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'countries',
      ).settings = firestoreSettings;
    } catch (e) {
      debugPrint('Firestore "countries" instance settings failed: $e');
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        initialCountryIdProvider.overrideWithValue(initialCountryId),
        cachedCountriesProvider.overrideWithValue(cachedCountries),
      ],
      child: const App(),
    ),
  );
}
